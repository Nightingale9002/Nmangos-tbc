#!/usr/bin/env python3
"""Versioned PlayerBots data packages. No numbered SQL or implicit database fallback."""
import argparse, base64, datetime, decimal, gzip, hashlib, json, os, re, sys
from pathlib import Path
import pymysql

PREFIX = 'ai_playerbot_'
RUNTIME = {'ahbot','bot_profile','combat_sample','db_store','random_bots','item_info_cache',
           'equip_cache','rarity_cache','rnditem_cache','tele_cache','rpg_tele_cache',
           'jump_obs','lift_obs','priority_obs','pull_log','stats'}
SEEDS = {'names','guild_names','arena_team_names'}

def ident(name):
    if not re.fullmatch(r'[A-Za-z0-9_]+', name): raise ValueError('Invalid identifier: '+name)
    return '`'+name+'`'

def encode(v):
    if isinstance(v,bytes): return {'$bytes':base64.b64encode(v).decode('ascii')}
    if isinstance(v,(decimal.Decimal,datetime.datetime,datetime.date,datetime.timedelta)): return str(v)
    return v

def decode(v):
    return base64.b64decode(v['$bytes']) if isinstance(v,dict) and set(v)=={'$bytes'} else v

def canonical(rows):
    return sorted(json.dumps([encode(x) for x in r],ensure_ascii=False,separators=(',',':')) for r in rows)

def digest(rows):
    return hashlib.sha256(('\n'.join(canonical(rows))+'\n').encode()).hexdigest()

def query(c,sql,args=None):
    with c.cursor() as x: x.execute(sql,args); return x.fetchall()

def tables(c,db): return {r[0] for r in query(c,'SHOW TABLES FROM '+ident(db)) if r[0].startswith(PREFIX)}

def schema(c,db,t):
    ddl=query(c,f'SHOW CREATE TABLE {ident(db)}.{ident(t)}')[0][1]
    ddl=re.sub(r' AUTO_INCREMENT=\d+','',ddl)
    return ddl

def columns(c,db,t): return [r[0] for r in query(c,f'SHOW COLUMNS FROM {ident(db)}.{ident(t)}')]

def schema_compatible(c,db,t,e):
    actual=query(c,f'SHOW COLUMNS FROM {ident(db)}.{ident(t)}')
    expected=dict(re.findall(r'`([A-Za-z0-9_]+)`\s+([A-Za-z]+(?:\([^)]*\))?(?: unsigned)?(?: zerofill)?)',e['ddl']))
    def datatype(value):
        return re.sub(r'\b(tinyint|smallint|mediumint|int|bigint)\(\d+\)',r'\1',value.lower())
    if [r[0] for r in actual]!=e['columns']:return False
    for row in actual:
        if row[0] not in expected or datatype(row[1])!=datatype(expected[row[0]]):return False
        declaration=re.search(r'`'+re.escape(row[0])+r'`\s+'+re.escape(expected[row[0]])+r'([^,\n]*)',e['ddl'])
        if ('NO' if 'NOT NULL' in declaration[1] else 'YES')!=row[2]:return False
    primary=re.search(r'PRIMARY KEY\s*\(([^)]*)\)',e['ddl'])
    expected_key=re.findall(r'`([^`]+)`',primary[1]) if primary else []
    actual_key=[r[4] for r in sorted(query(c,f'SHOW INDEX FROM {ident(db)}.{ident(t)}'),key=lambda r:r[3]) if r[2]=='PRIMARY']
    return actual_key==expected_key

def scope(t,policy):
    # Public strategies are replaced wholesale; private (owner<>0) rows are preserved.
    return ' WHERE owner=0' if t==PREFIX+'custom_strategy' and policy=='replace' else ''

def selected(c,db,t,policy):
    rows=query(c,f'SELECT * FROM {ident(db)}.{ident(t)}'+scope(t,policy))
    # Strategy ids are environment-local surrogate keys; policy identity is name/owner/idx.
    if t==PREFIX+'custom_strategy':
        index=columns(c,db,t).index('id')
        rows=[tuple(0 if i==index else v for i,v in enumerate(r)) for r in rows]
    return rows

def count(c,db,t,policy):
    # An empty result set is zero rows, never a missing table; presence comes from tables().
    return query(c,f'SELECT COUNT(*) FROM {ident(db)}.{ident(t)}'+scope(t,policy))[0][0]

def write_gzip(path,rows):
    # mtime=0 makes package bytes deterministic.
    with path.open('wb') as raw:
        with gzip.GzipFile(fileobj=raw,mode='wb',mtime=0,filename='') as stream:
            for row in canonical(rows): stream.write((row+'\n').encode())

def read_gzip(path):
    with gzip.open(path,'rt',encoding='utf8') as f:
        return [tuple(decode(x) for x in json.loads(line)) for line in f]

def policy_for(table):
    suffix=table[len(PREFIX):]
    return 'preserve' if suffix in RUNTIME or suffix.endswith(('_log','_obs','_cache')) else 'seed' if suffix in SEEDS else 'replace'

def resolve_sources(c,world,characters):
    """One source per bot table. Characters is authoritative; world is compatibility only.

    The old order let the world loop overwrite the characters owner, so a stale world copy
    silently replaced the authoritative characters table. A table that characters has is now
    never read from world, even when the world copy has more rows or a different schema.
    """
    primary=tables(c,characters);legacy=tables(c,world)
    plan={}
    for t in sorted(primary|legacy):
        if '_bak' in t: continue
        plan[t]=(characters,'characters') if t in primary else (world,'world')
    return plan

def ambiguity_hints(c,world,characters,plan):
    """Report duplicate tables whose world copy the old source order would have exported."""
    legacy=tables(c,world);hints=[]
    for t,(db,source) in sorted(plan.items()):
        if source!='characters' or t not in legacy: continue
        own=columns(c,characters,t);other=columns(c,world,t)
        if own!=other:
            hints.append(f'{t}: characters {len(own)} columns used, world copy has {len(other)} columns; legacy copy ignored')
            continue
        policy=policy_for(t)
        if policy!='preserve':
            mine=count(c,characters,t,policy);theirs=count(c,world,t,policy)
            if mine!=theirs:
                hints.append(f'{t}: characters {mine} rows used, world copy has {theirs} rows; no fallback to world')
    return hints

def export_package(c,out,world,characters,dry_run=False):
    plan=resolve_sources(c,world,characters)
    for hint in ambiguity_hints(c,world,characters,plan):
        print('warn',hint,flush=True)
    if not dry_run: out.mkdir(parents=True,exist_ok=True)
    manifest={'format':1,'target':'characters','tables':{}}
    for t,(db,source) in sorted(plan.items()):
        policy=policy_for(t)
        entry={'ddl':schema(c,db,t),'columns':columns(c,db,t),'policy':policy,'source':source}
        rows=None
        if policy!='preserve':
            if dry_run:
                rows=count(c,db,t,policy)
            else:
                rows=selected(c,db,t,policy);file=t+'.jsonl.gz';write_gzip(out/file,rows)
                entry.update(file=file,rows=len(rows),sha256=digest(rows),file_sha256=hashlib.sha256((out/file).read_bytes()).hexdigest())
                rows=len(rows)
        manifest['tables'][t]=entry
        print('plan' if dry_run else 'export',t,policy,source,'schema only' if rows is None else rows,flush=True)
    # This optional GM policy has a reader but was missing from the old installation chain.
    t=PREFIX+'dps_exempt'
    if t not in manifest['tables']:
        print('plan' if dry_run else 'export',t,'replace','synthetic',0,flush=True)
        if not dry_run:
            file=t+'.jsonl.gz';write_gzip(out/file,[])
            manifest['tables'][t]={'ddl':"CREATE TABLE `ai_playerbot_dps_exempt` (`map` int unsigned NOT NULL, `entry` int unsigned NOT NULL, `note` varchar(255) NOT NULL DEFAULT '', PRIMARY KEY (`map`,`entry`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",'columns':['map','entry','note'],'policy':'replace','source':'synthetic','file':file,'rows':0,'sha256':digest([]),'file_sha256':hashlib.sha256((out/file).read_bytes()).hexdigest()}
    if not dry_run: (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    return manifest

def load_package(path):
    m=json.loads((path/'manifest.json').read_text(encoding='utf8'))
    if m.get('format')!=1 or m.get('target')!='characters': raise ValueError('Unsupported package')
    for t,e in m['tables'].items():
        ident(t)
        if not t.startswith(PREFIX) or '_bak' in t: raise ValueError('Non-bot table in package')
        if e['policy'] not in {'replace','preserve','seed'}: raise ValueError('Unknown policy')
        if 'file' in e:
            f=path/e['file']
            if f.name!=e['file'] or f.suffix!='.gz': raise ValueError('Invalid data path')
            if hashlib.sha256(f.read_bytes()).hexdigest()!=e['file_sha256']: raise ValueError('Corrupt file: '+t)
            rows=read_gzip(f)
            if len(rows)!=e['rows'] or digest(rows)!=e['sha256']: raise ValueError('Corrupt data: '+t)
            if any(len(r)!=len(e['columns']) for r in rows): raise ValueError('Wrong column count: '+t)
    return m

def backup(c,db,t,out):
    # External backup, never *_bak_* tables in either live schema.
    out.mkdir(parents=True,exist_ok=True)
    ddl=schema(c,db,t);rows=query(c,f'SELECT * FROM {ident(db)}.{ident(t)}')
    stem=db+'.'+t
    if (out/(stem+'.schema.json')).exists() or (out/(stem+'.jsonl.gz')).exists():
        raise ValueError('Backup already exists; choose a new backup directory: '+str(out))
    (out/(stem+'.schema.json')).write_text(json.dumps({'ddl':ddl,'columns':columns(c,db,t),'rows':len(rows),'sha256':digest(rows)},ensure_ascii=False,indent=2),encoding='utf8')
    write_gzip(out/(stem+'.jsonl.gz'),rows)

def install(c,path,world,target,apply,backup_dir):
    m=load_package(path);current=tables(c,target);legacy=tables(c,world)
    if target==world: raise ValueError('Character and world databases must differ')
    if apply and not backup_dir: raise ValueError('--backup-dir required for apply')
    for t,e in m['tables'].items():
        if t in current and not schema_compatible(c,target,t,e):
            raise ValueError('Existing schema differs; explicit schema migration required: '+t)
        if t not in current and t in legacy and e['policy'] in {'preserve','seed'} and not schema_compatible(c,world,t,e):
            raise ValueError('Legacy runtime schema differs; explicit schema migration required before copying: '+t)
    for t,e in m['tables'].items():
        policy=e['policy'];exists=t in current
        print('import',t,policy,'existing' if exists else 'create',flush=True)
        if not apply: continue
        if exists and policy in {'preserve','seed'}: continue
        if t in legacy and policy in {'preserve','seed'}:
            backup(c,world,t,backup_dir)
            query(c,f'CREATE TABLE {ident(target)}.{ident(t)} LIKE {ident(world)}.{ident(t)}')
            query(c,f'INSERT INTO {ident(target)}.{ident(t)} SELECT * FROM {ident(world)}.{ident(t)}')
            current.add(t);continue
        if exists:
            backup(c,target,t,backup_dir)
            if columns(c,target,t)!=e['columns']:
                raise ValueError('Existing schema differs; explicit schema migration required: '+t)
            if policy=='replace' and 'ENGINE=InnoDB' not in schema(c,target,t):
                query(c,f'ALTER TABLE {ident(target)}.{ident(t)} ENGINE=InnoDB')
        if not exists:
            ddl=e['ddl'].replace('CREATE TABLE '+ident(t),'CREATE TABLE '+ident(target)+'.'+ident(t),1)
            ddl=re.sub(r'ENGINE=\w+','ENGINE=InnoDB',ddl)
            ddl=re.sub(r' ROW_FORMAT=\w+','',ddl)
            query(c,ddl)
        if 'file' in e:
            rows=read_gzip(path/e['file'])
            insert_columns=e['columns']
            if t==PREFIX+'custom_strategy':
                id_index=e['columns'].index('id')
                insert_columns=[v for v in e['columns'] if v!='id']
                rows=[tuple(v for i,v in enumerate(r) if i!=id_index) for r in rows]
            cols=','.join(ident(x) for x in insert_columns)
            try:
                c.begin()
                if t==PREFIX+'custom_strategy':
                    if t in legacy:
                        private=query(c,f'SELECT * FROM {ident(world)}.{ident(t)} WHERE owner<>0')
                        if private:
                            keys=[e['columns'].index(k) for k in ('name','owner','idx')]
                            existing={tuple(r[k] for k in keys):r for r in query(c,f'SELECT * FROM {ident(target)}.{ident(t)} WHERE owner<>0')}
                            missing=[]
                            for r in private:
                                key=tuple(r[k] for k in keys)
                                if key in existing and tuple(v for i,v in enumerate(existing[key]) if i!=id_index)!=tuple(v for i,v in enumerate(r) if i!=id_index): raise ValueError('Conflicting private strategy: '+str(key))
                                if key not in existing:
                                    missing.append(tuple(v for i,v in enumerate(r) if i!=id_index))
                                    existing[key]=r
                            if missing:
                                with c.cursor() as x: x.executemany(f'INSERT INTO {ident(target)}.{ident(t)} ({cols}) VALUES ('+','.join(['%s']*len(insert_columns))+')',missing)
                    query(c,f'DELETE FROM {ident(target)}.{ident(t)} WHERE owner=0')
                else:query(c,f'DELETE FROM {ident(target)}.{ident(t)}')
                if rows:
                    sql=f'INSERT INTO {ident(target)}.{ident(t)} ({cols}) VALUES ('+','.join(['%s']*len(insert_columns))+')'
                    with c.cursor() as x:
                        for start in range(0,len(rows),500): x.executemany(sql,rows[start:start+500])
                c.commit()
            except Exception:
                c.rollback();raise
        current.add(t)
    if apply: verify(c,path,target)

def verify(c,path,target):
    m=load_package(path);current=tables(c,target);errors=[]
    for t,e in m['tables'].items():
        if t not in current: errors.append(t+': missing');continue
        if not schema_compatible(c,target,t,e): errors.append(t+': schema differs');continue
        if e['policy']=='replace':
            rows=selected(c,target,t,e['policy'])
            if digest(rows)!=e['sha256'] or len(rows)!=e['rows']: errors.append(t+': content differs')
    if errors: raise ValueError('\n'.join(errors))
    print('verified',len(m['tables']),'tables; all replace rows match package')

def retire(c,path,world,target,apply,backup_dir):
    verify(c,path,target);m=load_package(path)
    source=sorted(tables(c,world))
    for t in source:
        if t not in m['tables']: raise ValueError('Unclassified world bot table: '+t)
        e=m['tables'][t]
        if e['policy'] in {'preserve','seed'}:
            if digest(query(c,f'SELECT * FROM {ident(world)}.{ident(t)}'))!=digest(query(c,f'SELECT * FROM {ident(target)}.{ident(t)}')):
                raise ValueError('Refuse to lose runtime/seed rows: '+t)
        if t==PREFIX+'custom_strategy':
            cols='name,idx,owner,action_line'
            wanted=set(query(c,f'SELECT {cols} FROM {ident(world)}.{ident(t)} WHERE owner<>0'))
            actual=set(query(c,f'SELECT {cols} FROM {ident(target)}.{ident(t)} WHERE owner<>0'))
            if not wanted.issubset(actual):raise ValueError('Unmigrated private strategies: '+t)
    for t in source:
        print('retire world table',t,flush=True)
        if apply:
            if not backup_dir: raise ValueError('--backup-dir required')
            backup(c,world,t,backup_dir);query(c,f'DROP TABLE {ident(world)}.{ident(t)}')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['export','check','import','verify','retire-world'])
    p.add_argument('--package',type=Path,required=True)
    p.add_argument('--host',default='127.0.0.1');p.add_argument('--port',type=int,default=3306)
    p.add_argument('--user',default='root');p.add_argument('--world',default='tbcmangos');p.add_argument('--characters',default='tbccharacters')
    p.add_argument('--apply',action='store_true');p.add_argument('--backup-dir',type=Path)
    p.add_argument('--dry-run',action='store_true',help='export only: print chosen source per table and write nothing')
    args=p.parse_args()
    if args.dry_run and args.action!='export': raise ValueError('--dry-run applies to export only')
    if args.action=='check':
        m=load_package(args.package);print('package valid:',len(m['tables']),'tables');return
    password=os.environ.get('PLAYERBOT_DB_PASSWORD')
    if password is None: raise ValueError('Set PLAYERBOT_DB_PASSWORD; never put a password on the command line')
    c=pymysql.connect(host=args.host,port=args.port,user=args.user,password=password,charset='utf8mb4',autocommit=True,read_timeout=120)
    try:
        if args.action=='export':export_package(c,args.package,args.world,args.characters,args.dry_run)
        elif args.action=='import':install(c,args.package,args.world,args.characters,args.apply,args.backup_dir)
        elif args.action=='verify':verify(c,args.package,args.characters)
        else:retire(c,args.package,args.world,args.characters,args.apply,args.backup_dir)
    finally:c.close()
if __name__=='__main__':
    try:main()
    except Exception as error:print('ERROR:',error,file=sys.stderr);sys.exit(1)
