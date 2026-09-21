/*
 * This file is part of the CMaNGOS Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "AuctionHouseBot.h"
#include "Common.h"
#include "Globals/ObjectMgr.h"
#include "Log/Log.h"
#include "Policies/Singleton.h"
#include "Util/ProgressBar.h"
#include "Server/DBCEnums.h"
#include "SystemConfig.h"
#include "World/World.h"

// Format is YYYYMMDDRR where RR is the change in the conf file
// for that day.
#define AUCTIONHOUSEBOT_CONF_VERSION    2021011201

// probe sell-order levels below the policy anchor (85% .. 45%)
static const uint32 AHBOT_PROBE_PCTS[5] = {85, 75, 65, 55, 45};

// [v2 2026-09-07] market-making scope is DATA-driven and nothing else: the operator
// decides the book entirely with ahbot_market_state rows (category=1 + enabled).
// The former class/subclass whitelist (IsManagedMmItem) and the loot-table universe
// computation were removed - IsMmBookItem() / IsCatalogItem() resolve purely from
// the operator rows loaded by LoadCatalogOverrides(). Rows themselves are created by
// the static dev/055 SQL (offline-computed droppable six-subclass set), so no item
// class knowledge is hard-coded here anymore.

INSTANTIATE_SINGLETON_1(AuctionHouseBot);

AuctionHouseBot::AuctionHouseBot() : m_configFileName(_AUCTIONHOUSEBOT_CONFIG), m_houseAction(-1)
{
}

AuctionHouseBot::~AuctionHouseBot()
{
}

void AuctionHouseBot::Initialize()
{
    if (!m_ahBotCfg.SetSource(m_configFileName, "Mangosd_"))
    {
        // set buy/sell chance to 0, this prevents Update() from accessing uninitialized variables
        m_chanceBuy = 0;
        m_chanceSell = 0;
        sLog.outString("AHBot is disabled. Unable to open configuration file(%s).", m_configFileName.c_str());
        return;
    }
    sLog.outString("AHBot using configuration file %s", m_configFileName.c_str());

    m_chanceSell = GetMinMaxConfig("AuctionHouseBot.Chance.Sell", 0, 100, 10);
    m_chanceBuy = GetMinMaxConfig("AuctionHouseBot.Chance.Buy", 0, 100, 10);

    sLog.outString("AHBot selling items: %s", m_chanceSell > 0 ? "Enabled" : "Disabled");
    sLog.outString("AHBot buying items: %s", m_chanceBuy > 0 ? "Enabled" : "Disabled");

    // NOTE: config loading below runs ALWAYS (not gated on Chance.Sell/Buy): the curated
    // market-maker catalog is driven by its own book, not by the legacy loot chances. The
    // loot-table flow itself stays chance-gated at runtime (Update()).
    {
        // creature loot
        ParseLootConfig("AuctionHouseBot.Loot.Creature.Normal", m_creatureLootNormalConfig);
        ParseLootConfig("AuctionHouseBot.Loot.Creature.Elite", m_creatureLootEliteConfig);
        ParseLootConfig("AuctionHouseBot.Loot.Creature.RareElite", m_creatureLootRareEliteConfig);
        ParseLootConfig("AuctionHouseBot.Loot.Creature.WorldBoss", m_creatureLootWorldBossConfig);
        ParseLootConfig("AuctionHouseBot.Loot.Creature.Rare", m_creatureLootRareConfig);
        FillUintVectorFromQuery("SELECT entry FROM creature_template WHERE `rank` = 0 AND entry IN (SELECT entry FROM creature_loot_template)", m_creatureLootNormalTemplates);
        FillUintVectorFromQuery("SELECT entry FROM creature_template WHERE `rank` = 1 AND entry IN (SELECT entry FROM creature_loot_template)", m_creatureLootEliteTemplates);
        FillUintVectorFromQuery("SELECT entry FROM creature_template WHERE `rank` = 2 AND entry IN (SELECT entry FROM creature_loot_template)", m_creatureLootRareEliteTemplates);
        FillUintVectorFromQuery("SELECT entry FROM creature_template WHERE `rank` = 3 AND entry IN (SELECT entry FROM creature_loot_template)", m_creatureLootWorldBossTemplates);
        FillUintVectorFromQuery("SELECT entry FROM creature_template WHERE `rank` = 4 AND entry IN (SELECT entry FROM creature_loot_template)", m_creatureLootRareTemplates);

        // disenchant loot
        ParseLootConfig("AuctionHouseBot.Loot.Disenchant", m_disenchantLootConfig);
        FillUintVectorFromQuery("SELECT DISTINCT entry FROM disenchant_loot_template", m_disenchantLootTemplates);

        // fishing loot
        ParseLootConfig("AuctionHouseBot.Loot.Fishing", m_fishingLootConfig);
        FillUintVectorFromQuery("SELECT DISTINCT entry FROM fishing_loot_template", m_fishingLootTemplates);

        // gameobject loot
        ParseLootConfig("AuctionHouseBot.Loot.Gameobject", m_gameobjectLootConfig);
        FillUintVectorFromQuery("SELECT DISTINCT entry FROM gameobject_loot_template WHERE entry IN (SELECT data1 FROM gameobject_template WHERE entry IN (SELECT id FROM gameobject WHERE spawntimesecsmax > 0))", m_gameobjectLootTemplates);

        // skinning loot
        ParseLootConfig("AuctionHouseBot.Loot.Skinning", m_skinningLootConfig);
        FillUintVectorFromQuery("SELECT DISTINCT entry FROM skinning_loot_template", m_skinningLootTemplates);

        // item loot (openable items: clams -> meat/pearls, etc.) - these drops are
        // NOT part of the market-maker catalog (e.g. Golden Pearl is class 3); they
        // flow through the normal loot-table supply so gems from clams etc. still
        // reach the AH. ONLY openable items that drop from monsters/world are
        // simulated (clams, low lockboxes...); exchange/reward containers like the
        // Sunwell cache (34548 -> flasks) are NOT monster drops and stay closed.
        ParseLootConfig("AuctionHouseBot.Loot.Item", m_itemLootConfig);
        FillUintVectorFromQuery("SELECT DISTINCT entry FROM item_loot_template "
            "WHERE entry IN (SELECT item FROM creature_loot_template "
            "UNION SELECT item FROM gameobject_loot_template "
            "UNION SELECT item FROM fishing_loot_template "
            "UNION SELECT item FROM skinning_loot_template)", m_itemLootTemplates);

        // profession items (different than the loot above, but use similar config)
        ParseLootConfig("AuctionHouseBot.Items.Profession", m_professionItemsConfig);
        FillUintVectorFromQuery("SELECT entry FROM item_template WHERE entry IN (SELECT EffectItemType1 FROM spell_template WHERE attributes & 32 AND attributes & 65536)", m_professionItems);

        // item level constraints (sets RequiredLevel and ItemLevel caps for items listed on the AH)
        ParseLevelConstraints();

        // vendor items (used to prevent items being bought from vendor and sold at ah for profit)
        // [2026-09-19] Only vendors that actually exist in the world count. A npc_vendor row whose
        // NPC has no spawn point in `creature` can never be reached by a player, so treating its
        // stock as "vendor price" (GetItemValue() -> 100) only misprices the item. Measured on this
        // server: of 788 vendor NPCs, 27 have no spawn; they made 1,043 items (677 of them epic
        // equipment) lose vendor status entirely and drop to their class value - e.g. 31334 was
        // priced 67.17g instead of 16.79g. Mirrors the spawn check the gameobject source already
        // does above. Note this is a strict subset: items also sold by a spawned vendor stay in.
        std::vector<uint32> tmpVector;
        FillUintVectorFromQuery("SELECT item FROM npc_vendor WHERE entry IN (SELECT id FROM creature)", tmpVector);
        std::copy(tmpVector.begin(), tmpVector.end(), std::inserter(m_vendorItems, m_vendorItems.end()));

        // item value
        ParseItemValueConfig("AuctionHouseBot.Value.Poor", m_itemValue[ITEM_QUALITY_POOR]);
        ParseItemValueConfig("AuctionHouseBot.Value.Normal", m_itemValue[ITEM_QUALITY_NORMAL]);
        ParseItemValueConfig("AuctionHouseBot.Value.Uncommon", m_itemValue[ITEM_QUALITY_UNCOMMON]);
        ParseItemValueConfig("AuctionHouseBot.Value.Rare", m_itemValue[ITEM_QUALITY_RARE]);
        ParseItemValueConfig("AuctionHouseBot.Value.Epic", m_itemValue[ITEM_QUALITY_EPIC]);
        ParseItemValueConfig("AuctionHouseBot.Value.Legendary", m_itemValue[ITEM_QUALITY_LEGENDARY]);
        ParseItemValueConfig("AuctionHouseBot.Value.Artifact", m_itemValue[ITEM_QUALITY_ARTIFACT]);

        // subclass-level value overrides, e.g. AuctionHouseBot.Value.Subclass.7.12.Normal for enchanting materials
        // Format: AuctionHouseBot.Value.Subclass.<Class>.<SubClass>.<Quality>
        //   -1 or absent: no override (use class/quality table); 0: disable this subclass/quality
        static const char* qualityNames[MAX_ITEM_QUALITY] = { "Poor", "Normal", "Uncommon", "Rare", "Epic", "Legendary", "Artifact" };
        for (uint32 cls = 0; cls < MAX_ITEM_CLASS; ++cls)
        {
            for (uint32 sub = 0; sub < 21; ++sub)
            {
                for (uint32 q = 0; q < MAX_ITEM_QUALITY; ++q)
                {
                    char subKey[96];
                    snprintf(subKey, sizeof(subKey), "AuctionHouseBot.Value.Subclass.%u.%u.%s", cls, sub, qualityNames[q]);
                    int32 subValue = m_ahBotCfg.GetIntDefault(subKey, -1);
                    if (subValue >= 0)
                    {
                        auto itr = m_itemSubclassValue.find(std::make_pair(cls, sub));
                        if (itr == m_itemSubclassValue.end())
                        {
                            std::array<int32, MAX_ITEM_QUALITY> values;
                            values.fill(-1);
                            itr = m_itemSubclassValue.emplace(std::make_pair(cls, sub), values).first;
                        }
                        itr->second[q] = subValue;
                    }
                }
            }
        }

        // item value for items sold by vendors
        m_vendorValue = m_ahBotCfg.GetBoolDefault("AuctionHouseBot.Value.Vendor", true);

        // item value variance
        m_valueVariance = GetMinMaxConfig("AuctionHouseBot.Value.Variance", 0, 100, 10);

        // auction min/max bid
        m_auctionBidMin = GetMinMaxConfig("AuctionHouseBot.Bid.Min", 0, 100, 75);
        m_auctionBidMax = GetMinMaxConfig("AuctionHouseBot.Bid.Max", 0, 100, 90);
        if (m_auctionBidMin > m_auctionBidMax)
        {
            sLog.outError("AHBot error: AuctionHouseBot.Bid.Min must be less or equal to AuctionHouseBot.Bid.Max. Setting Bid.Min equal to Bid.Max.");
            m_auctionBidMin = m_auctionBidMax;
        }

        // auction min/max time
        m_auctionTimeMin = GetMinMaxConfig("AuctionHouseBot.Time.Min", 1, 72, 2);
        m_auctionTimeMax = GetMinMaxConfig("AuctionHouseBot.Time.Max", 1, 72, 24);
        if (m_auctionTimeMin > m_auctionTimeMax)
        {
            sLog.outError("AHBot error: AuctionHouseBot.Time.Min must be less or equal to AuctionHouseBot.Time.Max. Setting Time.Min equal to Time.Max.");
            m_auctionTimeMin = m_auctionTimeMax;
        }

        // buy item value
        m_buyValue = GetMinMaxConfig("AuctionHouseBot.Buy.Value", 0, 200, 90);

        // overridden items (now folded into ahbot_market_state; only rows where an
        // override is actually set are loaded - catalog defaults carry 0 and must
        // NOT be interpreted as an operator override)
        auto queryResult = CharacterDatabase.PQuery("SELECT DISTINCT item, override_base_price, override_add_chance, override_min_amount, override_max_amount FROM ahbot_market_state "
                                                    "WHERE auction_house = 2 AND (override_base_price != 0 OR override_add_chance != 0 OR override_min_amount != 0 OR override_max_amount != 0)");
        if (queryResult)
        {
            do
            {
                Field* fields = queryResult->Fetch();
                uint32 itemId = fields[0].GetUInt32();
                AuctionHouseBotItemData itemData;
                itemData.Value = fields[1].GetUInt32();
                itemData.AddChance = fields[2].GetUInt32();
                itemData.MinAmount = fields[3].GetUInt32();
                itemData.MaxAmount = fields[4].GetUInt32();
                m_itemData[itemId] = itemData;
            }
            while (queryResult->NextRow());
        }

        // market-maker ladder quoting (currently applies to trade goods / Class 7 only)
        m_marketEnabled = m_ahBotCfg.GetBoolDefault("AuctionHouseBot.Value.Dynamic", false);
        m_marketRefresh = m_ahBotCfg.GetIntDefault("AuctionHouseBot.Value.DynamicRefresh", 60);
        // LadderStep is both the sell-tier spacing and the price-discovery move size:
        // a big step (e.g. 50 or 100) finds the equilibrium price fast when tiers get
        // bought out, a small step (1) gives a fine-grained book at the cost of slow
        // price discovery.
        m_mmLadderStep  = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.LadderStep", 50);
        m_mmLadderDepth = std::min<uint32>(MARKET_MAKER_MAX_LADDER, std::max<uint32>(1, m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.LadderDepth", 10)));
        m_mmBuyDepth    = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.BuyDepth", 10);
        m_mmBuyPerCycle = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.BuyPerCycle", 0);
        // [2026-09-18] 熔断②：每周期全局金币上限（铜）；0 = 不限制
        m_mmMaxGoldPerCycle = uint64(m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.MaxGoldPerCycle", 0));
        // [2026-09-18] 熔断③（主闸）：每 24h 全局金币上限（铜）；0 = 不限制。云端 = 5000 金。
        m_mmMaxGoldPerDay = uint64(m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.MaxGoldPerDay", 0));
        // [2026-09-18] 报价每日上下移动限额（%）；0 = 不限制
        m_mmMaxDailyMovePct = uint32(std::max<int32>(0, m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.MaxDailyMovePct", 0)));
        m_mmBidOnlyBuyout = m_ahBotCfg.GetBoolDefault("AuctionHouseBot.MarketMaker.BidOnlyBuyout", true);
        m_mmSmoothing   = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.Smoothing", 50);
        m_mmIdleThreshold = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.IdleThreshold", 60);
        m_mmIdleDecay   = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.IdleDecay", 5);
        m_mmRepriceThreshold = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.RepriceThreshold", 1);
        m_mmMaxItemUnits = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.MaxItemUnits", 200);
        m_mmEatRatio     = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.EatRatio", 50);
        // [2026-09-05] probes disabled (0): no sub-reference price-discovery orders
        m_mmProbeUnits   = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.ProbeUnits", 0);
        m_mmPriceFloor  = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.PriceFloor", 5);
        m_mmPriceCeil   = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.PriceCeil", 300);
        // curated catalog book (v3: exposure-slice quoting, no virtual inventory)
        m_catalogEnabled       = m_ahBotCfg.GetBoolDefault("AuctionHouseBot.MarketMaker.CatalogEnabled", true);
        m_catalogTarget        = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.CatalogTarget", 50);
        m_catalogCapacity      = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.CatalogCapacity", 200);
        m_catalogListBatch     = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.ListBatch", 25);
        m_catalogExposurePct   = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.QuoteExposurePct", 25);
        m_catalogExposurePct   = std::max<uint32>(1, std::min<uint32>(100, m_catalogExposurePct));
        m_catalogDemandBoostPct = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.DemandBoostPct", 50);
        m_catalogIdleDecayPct  = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.IdleTargetDecayPct", 5);
        m_flowRatio      = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.FlowRatio", 150);
        m_flowMoveDownPct = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.FlowMoveDownPct", 5);
        m_flowMoveUpPct  = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.FlowMoveUpPct", 1);
        m_flowMinUnits   = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.FlowMinUnits", 20);
        m_flowSettleHours = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.FlowSettleHours", 24);
        m_depthHighPct   = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.DepthTargetHighPct", 200);
        m_depthLowPct    = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.DepthTargetLowPct", 50);
        m_depthStepPct   = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.DepthStepPct", 5);
        m_transitionItemLevel = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.TransitionItemLevel", 40);
        m_transitionTargetMult = m_ahBotCfg.GetIntDefault("AuctionHouseBot.MarketMaker.TransitionTargetMult", 3);
        LoadCatalogOverrides();
        LoadInventory();
        if (m_marketEnabled)
        {
            // [v3-fix 2026-09-07] NO m_marketState.clear() here: LoadInventory() just
            // created a state per operator row (house 2) and clearing it would leave
            // only the price_ref>0 items re-created below - every other book item then
            // had NO state, QuoteCatalog hit GetMarketState()==nullptr for 96/118 and
            // nothing was ever listed. The loop below only restores persisted quotes
            // onto the existing states (operator[] keeps them).
            // load persisted quotes (the previous day's closing price) - the database
            // is the price source; today's ladder is anchored on it
            if (auto marketResult = CharacterDatabase.Query("SELECT item, price_ref AS price, auction_house FROM ahbot_market_state WHERE price_ref > 0"))
            {
                do
                {
                    Field* mfields = marketResult->Fetch();
                    uint32 itemId  = mfields[0].GetUInt32();
                    uint32 price   = mfields[1].GetUInt32();
                    uint32 house   = mfields[2].GetUInt32();
                    if (house < MAX_AUCTION_HOUSE_TYPE)
                    {
                        AuctionHouseBotMarketState& state = m_marketState[itemId][house];
                        // clamp stale persisted quotes into [floor, ceil] - historical
                        // crash values (e.g. below the vendor buy-back price) must
                        // not re-anchor the ladder on restart
                        uint32 clamped = price;
                        // [AHBOT-2026-09-04] operator-pinned goods (explicit price in the
                        // new table): operator price is authoritative - never clamp it
                        // into the legacy static BuyPrice-based [floor, ceil] band
                        AuctionHouseBotCatalogEntry op = GetCatalogEntry(itemId);
                        bool opPinned = op.enabled && op.price > 0 && (op.category == 1 || op.category == 2);
                        if (!opPinned)
                        {
                            if (ItemPrototype const* proto = ObjectMgr::GetItemPrototype(itemId))
                            {
                                uint32 staticPrice = CalculateBuyoutPrice(proto);
                                uint32 lo = staticPrice ? (uint32)((uint64)staticPrice * std::min<uint32>(100, m_mmPriceFloor) / 100) : 0;
                                if (proto->SellPrice > lo)
                                    lo = proto->SellPrice;
                                // [2026-09-20] PriceCeil = 0 now really means "no ceiling".
                                // The old std::max<uint32>(100, ...) turned 0 into "ceiling ==
                                // staticPrice" (3x TIGHTER than the 300 default) - the exact
                                // opposite of what an operator writing 0 expects.
                                uint32 hi = (staticPrice && m_mmPriceCeil)
                                                ? (uint32)((uint64)staticPrice * std::max<uint32>(100, m_mmPriceCeil) / 100) : 0;
                                if (lo && clamped < lo)
                                    clamped = lo;
                                if (hi && clamped > hi)
                                    clamped = hi;
                            }
                        }
                        state.price = clamped;
                        state.ref = clamped;
                        state.median = clamped;
                    }
                }
                while (marketResult->NextRow());
            }
        }

    }
}

// [rebuild-guard] while .ahbot rebuild runs its rapid Update() loop the market scan
// cannot refresh the booked snapshot, so quoting (catalog AND legacy loot supply)
// there would pile listings up again (the wall). Rebuild only expires; supply
// resumes at normal scan pace afterwards.
static bool s_ahbotRebuildSuppressQuote = false;

void AuctionHouseBot::Update()
{
    // refresh real market prices on a timer (independent of the sell/buy cycle)
    if (m_marketEnabled)
    {
        uint32 now = time(nullptr);
        if (now - m_lastMarketUpdateTime >= m_marketRefresh)
        {
            UpdateMarketPrices();
            m_lastMarketUpdateTime = now;
        }
    }

    if (++m_houseAction >= MAX_AUCTION_HOUSE_TYPE * 2)
        m_houseAction = 0;

    AuctionHouseType houseType = AuctionHouseType(m_houseAction % MAX_AUCTION_HOUSE_TYPE);
    // with linked auction houses (AllowTwoSide.Interaction.Auction=1) players only
    // ever see the NEUTRAL map; routing supply/scan/buy to the faction maps would
    // create listings that are invisible until the next restart
    uint32 houseIdx = EffectiveHouseIndex(houseType);
    AuctionHouseObject* auctionHouse = sAuctionMgr.GetAuctionsMap(AuctionHouseType(houseIdx));
    // legacy Chance.Buy roll; the curated catalog book absorbs regardless of the roll
    bool chanceBuy = m_chanceBuy > 0 && urand(0, 99) < m_chanceBuy;
    if (m_houseAction < MAX_AUCTION_HOUSE_TYPE)
    {
	// Lazy-refresh dynamic level
	if (m_useDynamicMaxLevel)
	{
	    uint32 now = time(nullptr);
	    if (now - m_lastLevelUpdateTime >= m_levelRefreshInterval)
	    {
		UpdateDynamicMaxLevel();
		CalculateItemLevelCap();
		m_lastLevelUpdateTime = now;
	    }
	}
        // ---- curated catalog book: exposure-backed quotes (price management only) ----
        // [v3 2026-09-07] virtual inventory is abandoned: the market maker keeps every
        // book item quoted to its exposure slice and lets the price machinery manage
        // it. Supply is the MM mint (no RefillCatalog inventory ledger anymore), so a
        // restart/expiry can never corrupt a stock count. Only the legacy loot-table
        // supply (below) keeps its chance gate.
        if (m_marketEnabled && m_catalogEnabled)
        {
            QuoteCatalog(auctionHouse, houseIdx);
        }

        // loot-table supply is chance-gated; suppressed entirely during .ahbot rebuild
        if (!s_ahbotRebuildSuppressQuote && urand(0, 99) < m_chanceSell)
        {
        // Sell items - loot-table based supply for everything outside the catalog
        std::unordered_map<uint32, uint32> itemMap;

        AddLootToItemMap(&LootTemplates_Creature, m_creatureLootNormalConfig, m_creatureLootNormalTemplates, itemMap);       // normal creature loot
        AddLootToItemMap(&LootTemplates_Creature, m_creatureLootEliteConfig, m_creatureLootEliteTemplates, itemMap);         // elite creature loot
        AddLootToItemMap(&LootTemplates_Creature, m_creatureLootRareEliteConfig, m_creatureLootRareEliteTemplates, itemMap); // rare elite creature loot
        AddLootToItemMap(&LootTemplates_Creature, m_creatureLootWorldBossConfig, m_creatureLootWorldBossTemplates, itemMap); // world boss creature loot
        AddLootToItemMap(&LootTemplates_Creature, m_creatureLootRareConfig, m_creatureLootRareTemplates, itemMap);           // rare creature loot

        AddLootToItemMap(&LootTemplates_Disenchant, m_disenchantLootConfig, m_disenchantLootTemplates, itemMap);             // disenchant loot
        AddLootToItemMap(&LootTemplates_Fishing, m_fishingLootConfig, m_fishingLootTemplates, itemMap);                      // fishing loot
        AddLootToItemMap(&LootTemplates_Gameobject, m_gameobjectLootConfig, m_gameobjectLootTemplates, itemMap);             // gameobject loot
        AddLootToItemMap(&LootTemplates_Skinning, m_skinningLootConfig, m_skinningLootTemplates, itemMap);                   // skinning loot
        AddLootToItemMap(&LootTemplates_Item, m_itemLootConfig, m_itemLootTemplates, itemMap);                                // item loot (clams, openable items)

        // profession items are a bit different (not looted)
        if (m_professionItemsConfig[1] > 0 && m_professionItemsConfig[3] > 0 && m_professionItems.size() > 0)
        {
            int32 maxTemplates = m_professionItemsConfig[0] < 0 ? urand(0, m_professionItemsConfig[1] - m_professionItemsConfig[0]) + m_professionItemsConfig[0] : urand(m_professionItemsConfig[0], m_professionItemsConfig[1]);
            if (maxTemplates > 0)
            {
                for (int32 templateCounter = 0; templateCounter < maxTemplates; ++templateCounter)
                {
                    uint32 item = m_professionItems[urand(0, m_professionItems.size() - 1)];
                    ItemPrototype const* prototype = ObjectMgr::GetItemPrototype(item);
                    if (prototype && (prototype->RequiredLevel > m_maxRequiredLevel || prototype->ItemLevel > m_maxItemLevel))
                        continue; // skip items too high level
                    if (!prototype || prototype->Quality == 0 || urand(0, (convertEnumToFlag(prototype->Quality)) - 1) > 0)
                        continue;
                    uint32 count = (uint32) round((uint64)prototype->GetMaxStackSize() * urand(m_professionItemsConfig[2], m_professionItemsConfig[3]) / 100.0);
                    if (count <= 0)
                        count = 1;
                    itemMap[item] += count;
                }
            }
        }

        // remove items we've overridden (AddChance > 0) and add using given AddChance and stack size
        for (auto& itemData : m_itemData)
        {
            if (itemData.second.AddChance > 0) // replace normal loot sources with custom chance of adding item
            {
                // [level-guard] overridden items still honour the max-level filters
                if (ItemPrototype const* op = ObjectMgr::GetItemPrototype(itemData.first))
                    if (op->RequiredLevel > m_maxRequiredLevel || op->ItemLevel > m_maxItemLevel)
                        continue;
                itemMap[itemData.first] = urand(0, 99) < itemData.second.AddChance ? urand(itemData.second.MinAmount, itemData.second.MaxAmount) : 0;
            }
        }

        for (auto& itemEntry : itemMap)
        {
            ItemPrototype const* prototype = ObjectMgr::GetItemPrototype(itemEntry.first);
            if (!prototype || prototype->GetMaxStackSize() == 0)
                continue; // really shouldn't happen, but better safe than sorry
            auto iterator = m_itemData.find(prototype->ItemId);
            if (iterator != m_itemData.end() && iterator->second.Value == 0)
                continue; // item is blacklisted
            if (iterator == m_itemData.end() || iterator->second.AddChance == 0)
            {
                if (prototype->Bonding == BIND_WHEN_PICKED_UP || prototype->Bonding == BIND_QUEST_ITEM)
                    continue; // no BoP and quest items
                if (prototype->Flags & ITEM_FLAG_HAS_LOOT)
                    continue; // nor items containing loot
                if (GetItemValue(prototype) == 0)
                    continue; // item class/subclass is filtered out
            }

            // [mm-scope 2026-09-07] MM ladder applies to operator-book members (data:
            // market_state category=1 + universe), never to a hard-coded item class.
            bool isMM = (iterator == m_itemData.end() && m_marketEnabled && IsMmBookItem(prototype->ItemId));
            if (m_marketEnabled && m_catalogEnabled)
            {
                // [v2 2026-09-07] row-driven gate: an item with an operator row
                // (category 1/2 book or 3 ban) never flows through the legacy loot
                // supply; only no-row / category-0 (untouched) items keep the legacy
                // random-loot path. No item class or universe computation decides this.
                if (GetCatalogEntry(prototype->ItemId).category != 0)
                    continue;
            }
            AuctionHouseBotMarketState* mmState = isMM ? GetMarketState(prototype->ItemId, AuctionHouseType(houseIdx)) : nullptr;
            if (mmState && m_mmMaxItemUnits)
            {
                uint32 ownUnits = 0;
                for (uint32 t = 0; t < MARKET_MAKER_MAX_LADDER; ++t)
                    ownUnits += mmState->tierStock[t];
                if (ownUnits >= m_mmMaxItemUnits)
                    continue; // main book is full, stop adding supply for this item
            }

            uint32 itemWorth = iterator != m_itemData.end() ? iterator->second.Value : CalculateBuyoutPrice(prototype);
            // market-maker sell quote: the MAIN ladder sits above the reference price
            // (100%..150% of price, tier k = price*(100 + k*step)/100). Exact tier
            // prices (no variance jitter).
            bool ladderQuote = false;
            if (mmState && mmState->price)
            {
                uint32 step = GetLadderStep(mmState->price);
                uint32 mainDepth = std::min<uint32>(MARKET_MAKER_MAX_LADDER, (50 / std::max<uint32>(1, step)) + 1);
                uint32 tier = urand(0, mainDepth - 1);
                uint32 unitPrice = (uint32)(((uint64)mmState->price * (100 + tier * step) + 50) / 100);
                if (unitPrice)
                {
                    itemWorth = unitPrice;
                    ladderQuote = true;
                }
            }
            uint32 itemValue = ladderQuote ? itemWorth : ValueWithVariance(itemWorth);
            for (uint32 stackCounter = 0; stackCounter < itemEntry.second; stackCounter += prototype->GetMaxStackSize())
            {
                uint32 count = itemEntry.second - stackCounter > prototype->GetMaxStackSize() ? prototype->GetMaxStackSize() : itemEntry.second - stackCounter;
                // [overflow-guard] uint64 math, clamp to sane max buyout (200k gold)
                uint32 buyoutPrice = (uint32)std::min<uint64>((uint64)itemValue * count, 2000000000ull);
                Item* item = Item::CreateItem(itemEntry.first, count);
                if (buyoutPrice == 0 || !item)
                    continue; // don't put up items we don't know the value of
                uint32 bidPrice = std::min(buyoutPrice, buyoutPrice * (urand(m_auctionBidMin, m_auctionBidMax)) / 100);
                if (item)
                    auctionHouse->AddAuction(sAuctionHouseStore.LookupEntry(houseIdx == AUCTION_HOUSE_ALLIANCE ? 1 : (houseIdx == AUCTION_HOUSE_HORDE ? 6 : 7)), item, urand(m_auctionTimeMin, m_auctionTimeMax) * HOUR, bidPrice, buyoutPrice);
            }

            // probe order: one small sell order below the reference, placed only when
            // the current probe tier is empty and the cooldown elapsed - probes the
            // demand level one tier at a time (85% -> 75% -> ... -> 45% of price)
            if (mmState && mmState->price && m_mmProbeUnits)
            {
                static const uint32 PROBE_PCTS[5] = {85, 75, 65, 55, 45};
                uint32 level = std::min<uint32>(4, mmState->probeLevel);
                if (mmState->probeStock[level] < m_mmProbeUnits && mmState->probeCooldown == 0)
                {
                    uint32 probeUnitPrice = (uint32)(((uint64)mmState->price * PROBE_PCTS[level] + 50) / 100);
                    if (probeUnitPrice)
                    {
                        uint32 probeCount = m_mmProbeUnits - mmState->probeStock[level];
                        Item* probeItem = Item::CreateItem(prototype->ItemId, probeCount);
                        if (probeItem)
                        {
                            uint32 probeBuyout = (uint32)std::min<uint64>((uint64)probeUnitPrice * probeCount, 2000000000ull);
                            uint32 probeBid = std::min(probeBuyout, probeBuyout * (urand(m_auctionBidMin, m_auctionBidMax)) / 100);
                            auctionHouse->AddAuction(sAuctionHouseStore.LookupEntry(houseIdx == AUCTION_HOUSE_ALLIANCE ? 1 : (houseIdx == AUCTION_HOUSE_HORDE ? 6 : 7)), probeItem, urand(m_auctionTimeMin, m_auctionTimeMax) * HOUR, probeBid, probeBuyout);
                            // [probe-guard] mark the tier filled immediately so a probe is
                            // not re-placed every sell phase until the next market scan
                            if (mmState)
                                mmState->probeStock[level] += probeCount;
                        }
                    }
                }
            }
        }
        }
    } else if (m_houseAction >= MAX_AUCTION_HOUSE_TYPE && (chanceBuy || (m_marketEnabled && m_catalogEnabled)))
    {
        // Buy items (chance-gated legacy absorption OR the curated catalog book; the MM
        // absorbs its own book members regardless of Chance.Buy)
        AuctionHouseObject::AuctionEntryMapBounds bounds = auctionHouse->GetAuctionsBounds();
        std::vector<AuctionEntry*> buyoutAuctions;
        for (AuctionHouseObject::AuctionEntryMap::const_iterator itr = bounds.first; itr != bounds.second; ++itr)
        {
            AuctionEntry* auction = itr->second;
            if (auction->owner == 0)
                continue; // never trade with ourselves - a market maker does not buy its own sell orders
            Item* item = sAuctionMgr.GetAItem(auction->itemGuidLow);
            if (!item)
                continue; // shouldn't happen, but apparently it does(?)
            auto prototype = item->GetProto();
            if (!prototype)
                continue; // shouldn't happen
            auto iterator = m_itemData.find(prototype->ItemId);
            if (iterator != m_itemData.end() && iterator->second.Value == 0)
                continue; // item is blacklisted

            uint32 itemWorth = iterator != m_itemData.end() ? iterator->second.Value : CalculateBuyoutPrice(prototype);
            // [mm-scope 2026-09-07] MM-book absorption is DATA-driven: only operator
            // book members (market_state category=1 + universe, via IsMmBookItem) are
            // absorbed on MM terms regardless of Chance.Buy. The old Class==7 test
            // excluded gems and included non-book trade goods.
            bool isMMBuy = (iterator == m_itemData.end() && m_marketEnabled && IsMmBookItem(prototype->ItemId));
            // curated regulation scope: with the catalog enabled we only absorb items
            // the operator chose to make a market in
            if (isMMBuy && m_catalogEnabled && !IsCatalogItem(prototype->ItemId))
                continue;
            // legacy (non-MM book) absorption keeps the Chance.Buy roll; the MM book absorbs
            // regardless of Chance.Buy (driven by the catalog, not by the loot chance)
            if (!chanceBuy && !isMMBuy)
                continue;
            AuctionHouseBotMarketState* mmBuyState = isMMBuy ? GetMarketState(prototype->ItemId, AuctionHouseType(houseIdx)) : nullptr;
            // category 2 (vendor-price good): buy at the FIXED price (no BuyDepth discount
            // below it - a sub-vendor bid would just send players to the NPC vendor). Inert
            // until rows are marked category 2 with a price.
            uint32 fixedBuy = GetCatalogFixedPrice(prototype->ItemId);
            if (fixedBuy)
                itemWorth = fixedBuy;
            else if (mmBuyState && mmBuyState->price)
            {
                // hidden buy cap = price * (100 - BuyDepth) / 100 (modern exchange
                // style: the bid book is internal, not shown on the AH). This
                // replaces the old static-value absorption - oversupplied items
                // whose market price collapsed are no longer bought at the
                // inflated static price.
                uint32 bid = (uint32)((uint64)mmBuyState->price * (100 - m_mmBuyDepth) / 100);
                if (bid)
                    itemWorth = bid;
            }
            // [v3 2026-09-07] no warehouse capacity gate: virtual inventory is gone,
            // absorption is bounded by the per-cycle quota below (buyoutsThisCycle).
            uint32 buyItemCheck = (uint32)std::min<uint64>((uint64)ValueWithVariance(itemWorth) * item->GetCount(), 0xFFFFFFFFull);
            uint32 bidPrice = auction->bid + auction->GetAuctionOutBid();
            if (auction->startbid > bidPrice)
                bidPrice = auction->startbid;
            if (auction->buyout > 0 && buyItemCheck > auction->buyout)
            {
                // [2026-09-18] 熔断③（主闸）：每 24 小时全局金币上限。站长定案：
                //   按 50 人在线规模，每天最多释放 5000 金；在线时间不均匀 → 用"天"而不是"周期"。
                //   跨重启连续（RollDailyBudgetWindow + PersistDailyBudget）。
                RollDailyBudgetWindow();
                if (m_mmMaxGoldPerDay && m_dayGoldSpent + auction->buyout > m_mmMaxGoldPerDay)
                {
                    if (!m_dayBreakerTripped)
                    {
                        m_dayBreakerTripped = true;
                        sLog.outError("[AHBOT] BUY BREAKER TRIPPED (daily): 24h budget %llu copper (%.0f gold) exhausted, spent %llu copper (%.0f gold) - no more player buyouts in this window",
                            (unsigned long long)m_mmMaxGoldPerDay, double(m_mmMaxGoldPerDay) / 10000.0,
                            (unsigned long long)m_dayGoldSpent, double(m_dayGoldSpent) / 10000.0);
                    }
                    continue;
                }

                // [2026-09-18] 熔断②：每周期【全局】金币上限（站长定案 = 100 金）。
                //   站长口径：某个物品被抬到 100 金/组 → 说明供给很有限，**不应该继续收购**。
                //   所以这里是纯硬闸：单件挂单价格超过周期预算就永远不会被收（而不是推迟）。
                //   被跳过的挂单下一周期仍会重新扫到，但价格不掉下来就一直不买。
                if (m_mmMaxGoldPerCycle && m_cycleGoldSpent + auction->buyout > m_mmMaxGoldPerCycle)
                {
                    if (!m_cycleBreakerTripped)
                    {
                        m_cycleBreakerTripped = true;
                        sLog.outError("[AHBOT] BUY BREAKER TRIPPED (per-cycle): cycle budget %llu copper (%.0f gold) exhausted (spent %llu) - remaining player buyouts this cycle deferred",
                            (unsigned long long)m_mmMaxGoldPerCycle, double(m_mmMaxGoldPerCycle) / 10000.0,
                            (unsigned long long)m_cycleGoldSpent);
                    }
                    continue;
                }

                // market-maker buy quota: limit absorbed volume per item per cycle
                if (mmBuyState && m_mmBuyPerCycle)
                {
                    if (mmBuyState->buyoutsThisCycle + item->GetCount() > m_mmBuyPerCycle)
                        continue; // quota exhausted, skip this listing
                    mmBuyState->buyoutsThisCycle += item->GetCount();
                }
                m_cycleGoldSpent += auction->buyout;
                m_dayGoldSpent += auction->buyout;
                PersistDailyBudget();
                buyoutAuctions.push_back(auction); // can't buyout item here as that modifies the AuctionEntryMap, invalidating the iterator
            }
            else if (!m_mmBidOnlyBuyout && buyItemCheck > bidPrice)
                auction->UpdateBid(bidPrice);
        }
        for (auto auction : buyoutAuctions)
            auction->UpdateBid(auction->buyout);
    }
}

// Scan all auction houses for player listings and record the real per-unit market
// price (median buyout) per item and house. Persisted into ahbot_market_state (price_ref) so prices
// survive restarts and are visible/editable via the database.
void AuctionHouseBot::UpdateMarketPrices()
{
    // [2026-09-18] 熔断②：本刷新周期的【全局】金币预算从 0 起算（周期 ≈ m_marketRefresh）
    m_cycleGoldSpent = 0;
    m_cycleBreakerTripped = false;

    // scan only the maps players actually see: linked AHs collapse to NEUTRAL
    uint32 effHouses[MAX_AUCTION_HOUSE_TYPE];
    uint32 effCount = 0;
    if (sWorld.getConfig(CONFIG_BOOL_ALLOW_TWO_SIDE_INTERACTION_AUCTION))
        effHouses[effCount++] = AUCTION_HOUSE_NEUTRAL;
    else
        for (uint32 i = 0; i < MAX_AUCTION_HOUSE_TYPE; ++i)
            effHouses[effCount++] = i;

    for (uint32 hi = 0; hi < effCount; ++hi)
    {
        uint32 houseIndex = effHouses[hi];
        AuctionHouseType houseType = AuctionHouseType(houseIndex);
        AuctionHouseObject* auctionHouse = sAuctionMgr.GetAuctionsMap(houseType);

        // [booked-reset 2026-09-07] zero every book state's own-listing snapshot
        // BEFORE this scan buckets the real shelf. Without this, an item whose lots
        // fully sold/expired (so it is no longer in the house map) is never visited
        // by the scan loop and keeps a STALE booked count (~exposure) - QuoteCatalog
        // then sees exposure already full forever and never lists it again (the
        // "1-2 lots / empty shelf" deadlock). prevTierStock is snapshotted here so
        // the eaten-tier comparison keeps the previous scan's real bucket.
        for (auto& itemStates : m_marketState)
        {
            AuctionHouseBotMarketState& st = itemStates.second[houseIndex];
            st.prevTierStock = st.tierStock;
            st.tierStock.fill(0);
            st.probeStock.fill(0);
        }

        // item -> per-unit buyouts of ALL listings (players and ahbot: on this server
        // the ahbot itself is the visible market), plus player listings separately,
        // plus ahbot-owned AuctionEntry* per item for repricing
        std::map<uint32, std::vector<uint32>> listings;
        std::map<uint32, std::vector<uint32>> playerListings;
        std::map<uint32, uint32> playerUnits; // player-listing supply depth per item
        std::map<uint32, std::vector<AuctionEntry*>> ahbotListings;
        AuctionHouseObject::AuctionEntryMapBounds bounds = auctionHouse->GetAuctionsBounds();
        for (AuctionHouseObject::AuctionEntryMap::const_iterator itr = bounds.first; itr != bounds.second; ++itr)
        {
            AuctionEntry* auction = itr->second;
            if (auction->buyout == 0)
                continue; // no buyout, not usable for quoting
            Item* item = sAuctionMgr.GetAItem(auction->itemGuidLow);
            if (!item)
                continue;
            uint32 count = std::max<uint32>(1, item->GetCount());
            uint32 unitBuyout = auction->buyout / count;
            listings[item->GetEntry()].push_back(unitBuyout);
            if (auction->owner != 0)
            {
                playerListings[item->GetEntry()].push_back(unitBuyout);
                playerUnits[item->GetEntry()] += count;
            }
            else
                ahbotListings[item->GetEntry()].push_back(auction);
        }

        for (auto const& pair : listings)
        {
            uint32 itemId = pair.first;
            std::vector<uint32> sorted(pair.second.begin(), pair.second.end());
            std::sort(sorted.begin(), sorted.end());
            uint32 medianAll = sorted[sorted.size() / 2]; // upper median, robust to outliers

            AuctionHouseBotMarketState& state = m_marketState[itemId][houseIndex];
            state.median = medianAll;
            state.listingCount = uint32(pair.second.size()); // market depth (all listings)
            state.buyoutsThisCycle = 0; // reset buy quota each refresh cycle

            uint32 oldPrice = state.price;
            uint32 staticPrice = 0;
            if (ItemPrototype const* proto = ObjectMgr::GetItemPrototype(itemId))
                staticPrice = CalculateBuyoutPrice(proto);

            // category 2 (vendor-price good): price is FIXED at the operator row price;
            // the whole central-bank flow machinery below is bypassed (architecture:
            // inert until rows are marked category 2 with a price).
            if (uint32 fixedUnit = GetCatalogFixedPrice(itemId))
            {
                state.price = fixedUnit;
                state.ref = fixedUnit;
                state.median = medianAll ? medianAll : fixedUnit;
                if (state.price != oldPrice)
                {
                    // [no-insert 2026-09-07] update the operator row only - the server
                    // never creates market_state rows at runtime; the static 055 deploy
                    // SQL owns row creation.
                    CharacterDatabase.PExecute("UPDATE ahbot_market_state SET price_ref = %u WHERE item = %u AND auction_house = %u", state.price, itemId, houseIndex);
                }
                continue;
            }

            // [AHBOT-2026-09-04] operator-pinned market good: the row in the new table
            // (ahbot_market_state) carries an explicit operator price (e.g. 059
            // enchanting materials 22449/22450/20725 = category 1 with price > 0).
            // The operator price is authoritative for BOTH buy cap and sell ladder -
            // no legacy static BuyPrice clamp, no central-bank drift. Everything else
            // (non trade-goods, unpriced rows) keeps the old dynamic machinery.
            {
                AuctionHouseBotCatalogEntry op = GetCatalogEntry(itemId);
                if (op.enabled && op.category == 1 && op.price > 0)
                {
                    EnsureTargets(state, itemId);
                    if (state.price != op.price)
                    {
                        // [no-insert] update the existing operator row only (see above)
                        CharacterDatabase.PExecute("UPDATE ahbot_market_state SET price_ref = %u WHERE item = %u AND auction_house = %u", op.price, itemId, houseIndex);
                    }
                    state.price = op.price;
                    state.ref = op.price;
                    if (!state.median)
                        state.median = medianAll ? medianAll : op.price;
                    continue;
                }
            }

            // first-run seed and adaptive baseline
            if (!state.price && staticPrice)
                state.price = staticPrice;
            if (!state.ref && staticPrice)
                state.ref = staticPrice;

            // demand-responsive holding targets (transition goods get xmult supply)
            EnsureTargets(state, itemId);

            uint32 floor = staticPrice ? (uint32)((uint64)staticPrice * std::min<uint32>(100, m_mmPriceFloor) / 100) : 0;
            // the floor can never sit below the vendor buy-back price (SellPrice):
            // below it players buy from the AH and vendor for a guaranteed profit
            if (ItemPrototype const* proto = ObjectMgr::GetItemPrototype(itemId))
                if (proto->SellPrice > floor)
                    floor = proto->SellPrice;
            // [2026-09-20] PriceCeil = 0 now really means "no ceiling" (see the startup
            // clamp above): the old std::max<uint32>(100, ...) made 0 mean "ceiling ==
            // staticPrice", i.e. tighter than the default instead of unlimited.
            uint32 ceil  = (staticPrice && m_mmPriceCeil)
                               ? (uint32)((uint64)staticPrice * std::max<uint32>(100, m_mmPriceCeil) / 100) : 0;

            // drain player sales since the last scan
            uint32 soldUnits = 0, lastTradePrice = 0;
            sAuctionMgr.DrainSoldItems(itemId, houseIndex, soldUnits, lastTradePrice);
            state.soldUnits = soldUnits;

            // lowest player listing unit price (sell pressure / lower-bound signal)
            uint32 playerBestAsk = 0;
            auto pitr = playerListings.find(itemId);
            if (pitr != playerListings.end() && !pitr->second.empty())
            {
                playerBestAsk = pitr->second[0];
                for (uint32 v : pitr->second)
                    if (v < playerBestAsk)
                        playerBestAsk = v;
            }
            state.playerBestAsk = playerBestAsk;

            // current tier-0 stock (pre-reprice) for the net-depletion eaten check
            uint32 tier0Now = 0;
            if (state.price)
            {
                auto a0 = ahbotListings.find(itemId);
                if (a0 != ahbotListings.end())
                {
                    for (AuctionEntry* auction : a0->second)
                    {
                        Item* it = sAuctionMgr.GetAItem(auction->itemGuidLow);
                        if (!it)
                            continue;
                        uint32 unit = auction->buyout / std::max<uint32>(1, it->GetCount());
                        if (unit >= state.price && unit < (uint64)state.price * (100 + GetLadderStep(state.price)) / 100)
                            tier0Now += it->GetCount();
                    }
                }
            }

            // ---- central-bank price policy ----
            // The fair value is UNKNOWN: it is discovered from the market maker's
            // own order-flow imbalance (quantity, never inventory levels):
            //   - players flooding us with supply (bought >> sold) -> our price is
            //     too high -> nudge the anchor down so they stop dumping on us
            //   - players consuming our supply (sold >> bought) -> our price is too
            //     low -> nudge the anchor up
            //   - balanced or quiet -> the price holds (stability first)
            // The anchor moves at most FlowMovePct per FlowWindowScans scans and is
            // bounded by [floor, ceil] - the SellPrice floor prevents arbitrage.
            uint32 newPrice = oldPrice;
            if (soldUnits > 0)
            {
                state.idleScans = 0;
                // eaten check: the ask side is being consumed -> answer with more
                // supply (target up); the price itself follows the flow rule below
                if (state.prevTierStock[0] > 0 &&
                    (soldUnits >= (uint64)state.prevTierStock[0] * std::min<uint32>(100, m_mmEatRatio) / 100 ||
                     tier0Now < (uint64)state.prevTierStock[0] * (100 - std::min<uint32>(100, m_mmEatRatio)) / 100))
                {
                    state.probeLevel = 0;      // restart probing near the (higher) demand
                    state.probeCooldown = 0;
                    // [2026-09-04] no demand-boost target growth: holdings stay at the
                    // operator/DB target, so world-refill & quotes can never overflow
                    // it (a warehouse at capacity is exactly what blocks player sales).
                    // Fast quote turnover (QuoteExposurePct) already answers demand.
                }
                // probe outcome (observation only): a below-quote sale is demand
                // discovery - recorded for the operator, never a pricing input
                if (lastTradePrice && lastTradePrice < (uint64)oldPrice * 95 / 100)
                {
                    int best = 0;
                    uint64 bestDiff = ~0ull;
                    for (int i = 0; i < 5; ++i)
                    {
                        uint64 target = (uint64)oldPrice * AHBOT_PROBE_PCTS[i] / 100;
                        uint64 diff = lastTradePrice > target ? lastTradePrice - target : target - lastTradePrice;
                        if (diff < bestDiff)
                        {
                            bestDiff = diff;
                            best = i;
                        }
                    }
                    state.probeDemandLevel = std::max<uint32>(state.probeDemandLevel, best);
                    state.probeStaleScans = 0;
                    // advance the probe one tier deeper (one level per scan max)
                    if (state.probeCooldown)
                        --state.probeCooldown;
                    if (state.probeLevel < 4 && state.probeCooldown == 0)
                    {
                        state.probeLevel++;
                        state.probeCooldown = m_mmProbeInterval;
                    }
                }
            }
            else
            {
                ++state.idleScans;
                if (state.probeCooldown)
                    --state.probeCooldown;
                // supply contraction on idle (quantity, not a price cut): an unsold
                // probe or a quiet book is NOT a reason to lower the price
                if (state.idleScans >= m_mmIdleThreshold && state.target)
                {
                    uint32 baseline = GetBaselineTarget(itemId);
                    if (state.target > baseline)
                        state.target = std::max<uint32>(baseline, state.target - state.target * std::min<uint32>(100, m_catalogIdleDecayPct) / 100);
                }
            }
            // stale probe demand evidence fades after ~10 minutes of no outcomes
            if (++state.probeStaleScans > 60)
            {
                state.probeDemandLevel = 0xFF;
                state.probeStaleScans = 0;
            }

            // ---- long-period flow settlement (price anchor moves) ----
            // flowBought/flowSold accumulate across scans and restarts (persisted in
            // ahbot_market_state). Once per FlowSettleHours the anchor moves if the flow
            // is clearly one-sided; otherwise the price holds. The move is ASYMMETRIC:
            // overpriced (players flood us with supply) corrects down fast (5%),
            // underpriced (players consume us) rises very slowly (1%) - welfare
            // protection: prices never run away upward, but bad prices get fixed.
            {
                uint32 now = time(nullptr);
                if (oldPrice && (!state.lastSettleTime || now - state.lastSettleTime >= m_flowSettleHours * HOUR))
                {
                    uint32 flowTotal = state.flowBought + state.flowSold;
                    // [2026-09-20] settlement log - the ONLY way to tune FlowMinUnits /
                    // FlowRatio / FlowSettleHours from real data instead of guessing.
                    // NOTE: the counters are zeroed below either way, so flow that stays
                    // under the gate is DISCARDED, not carried into the next period.
                    const char* outcome = "under-gate";
                    if (flowTotal >= m_flowMinUnits)
                    {
                        if (state.flowBought > (uint64)state.flowSold * m_flowRatio / 100)
                        {
                            newPrice = (uint32)(((uint64)oldPrice * (100 - std::min<uint32>(50, m_flowMoveDownPct)) + 50) / 100);
                            outcome = "down";
                        }
                        else if (state.flowSold > (uint64)state.flowBought * m_flowRatio / 100)
                        {
                            // [2026-09-21] 去重后的单边性判定：涨价必须来自 ≥2 个不同买家。
                            // 单人自己反复买（"养价"）无论买多少都不算需求信号。
                            // 降价不设这个限制：单个玩家大量砸货本来就是"供给过剩"的真实信号，
                            // 且价格跌得快是该机制有意的保护（宁可低也不要虚高）。
                            if (state.soldBuyerCount >= 2)
                            {
                                newPrice = (uint32)(((uint64)oldPrice * (100 + std::min<uint32>(50, m_flowMoveUpPct)) + 50) / 100);
                                outcome = "up";
                            }
                            else
                                outcome = "up-blocked-1buyer";
                        }
                        else
                            outcome = "balanced";
                    }
                    if (flowTotal)
                        sLog.outError("[AHBOT] SETTLE item=%u house=%u bought=%u sold=%u total=%u gate=%u buyers=%u old=%u new=%u result=%s",
                                      itemId, uint32(houseIndex), state.flowBought, state.flowSold,
                                      flowTotal, m_flowMinUnits, state.soldBuyerCount, oldPrice, newPrice, outcome);
                    state.flowBought = 0;
                    state.flowSold = 0;
                    state.soldBuyerCount = 0;               // 买家去重集合随窗口清零
                    state.soldBuyers.fill(0);
                    state.lastSettleTime = now;
                    CharacterDatabase.PExecute("UPDATE ahbot_market_state SET flow_bought = 0, flow_sold = 0, last_settle_time = %u WHERE item = %u AND auction_house = %u",
                                               state.lastSettleTime, itemId, houseIndex);
                }
            }

            // ---- player-listing-depth supply regulation (every scan) ----
            // [2026-09-04] shrink-only: when players flood supply we step our target
            // down toward the baseline; the target never expands upward (that caused
            // warehouse overflow and blocked player sales). Expansion is handled by
            // the operator rows (target/capacity in the DB), not by the bot.
            {
                auto pUnits = playerUnits.find(itemId);
                uint32 depth = pUnits != playerUnits.end() ? pUnits->second : 0;
                if (state.target && state.capacity)
                {
                    uint32 baseline = GetBaselineTarget(itemId);
                    uint32 step = std::max<uint32>(1, state.target * std::min<uint32>(50, m_depthStepPct) / 100);
                    if (depth >= (uint64)state.target * std::max<uint32>(100, m_depthHighPct) / 100)
                        state.target = std::max<uint32>(baseline, state.target > step ? state.target - step : baseline);
                }
            }

            // last-trade EMA + rolling trade log (seed for future price-curve feature).
            // Only at-quote (main ladder) sales feed the realized-price EMA: below-quote
            // (probe/discount) sales are demand-discovery evidence (probeDemandLevel)
            // but must NOT drag the quote down - otherwise the bot's own discounted
            // probes would spiral the price toward the floor on a low-demand server.
            if (lastTradePrice)
            {
                state.tradeLog.push_back(std::make_pair(lastTradePrice, soldUnits));
                while (state.tradeLog.size() > 20)
                    state.tradeLog.pop_front();
                if (lastTradePrice >= (uint64)oldPrice * 95 / 100)
                {
                    if (state.lastTradeEMA)
                        state.lastTradeEMA = (uint32)(((uint64)lastTradePrice * m_mmSmoothing + (uint64)state.lastTradeEMA * (100 - m_mmSmoothing)) / 100);
                    else
                        state.lastTradeEMA = lastTradePrice;
                }
            }
            // adaptive baseline: only follows market signals down (never up on its own)
            if (playerBestAsk && playerBestAsk < state.ref)
                state.ref = playerBestAsk;
            if (state.lastTradeEMA && state.lastTradeEMA < state.ref)
                state.ref = state.lastTradeEMA;

            // clamp: seed first (a fresh item with newPrice==0 must get the static
            // anchor, not the floor), then bound into [floor, ceil]
            if (!newPrice)
                newPrice = oldPrice ? oldPrice : staticPrice;
            if (floor && newPrice < floor)
                newPrice = floor;
            if (ceil && newPrice > ceil)
                newPrice = ceil;

            // [2026-09-18] 报价"每日上下移动限额"（站长定案：一天最多 ±10%）。
            // 窗口 24h，窗口基准 day_price 持久化；窗口到期后用当前报价重设基准。
            // 作用：流水结算/探测再灵敏，报价一天也不会跳超过这个幅度（防止价格被一次性操作打飞）。
            if (m_mmMaxDailyMovePct && newPrice)
            {
                uint32 now = time(nullptr);
                if (!state.dayStart || now - state.dayStart >= 24 * HOUR)
                {
                    state.dayPrice = newPrice;
                    state.dayStart = now;
                    CharacterDatabase.PExecute("UPDATE ahbot_market_state SET day_price = %u, day_start = %u WHERE item = %u AND auction_house = %u",
                        state.dayPrice, state.dayStart, itemId, houseIndex);
                }
                if (state.dayPrice)
                {
                    uint32 cap = std::min<uint32>(100, m_mmMaxDailyMovePct);
                    uint32 lo = (uint32)((uint64)state.dayPrice * (100 - cap) / 100);
                    uint32 hi = (uint32)((uint64)state.dayPrice * (100 + cap) / 100);
                    if (newPrice < lo) newPrice = lo;
                    if (newPrice > hi) newPrice = hi;
                }
            }

            state.price = newPrice;
            state.deviation = (float)std::abs((int64)medianAll - (int64)newPrice) / std::max<uint32>(1, newPrice);

            // persist the closing quote (price) - the database is the price source.
            // [v2 2026-09-07] pure UPDATE of existing operator rows (category 1/2) only:
            // the server NEVER creates market_state rows at runtime and price_ref is
            // only meaningful for book members. Legacy loot lots have no row and are
            // simply not written.
            if (newPrice != oldPrice)
            {
                AuctionHouseBotCatalogEntry persistEntry = GetCatalogEntry(itemId);
                if (persistEntry.enabled && (persistEntry.category == 1 || persistEntry.category == 2))
                    CharacterDatabase.PExecute("UPDATE ahbot_market_state SET price_ref = %u WHERE item = %u AND auction_house = %u", newPrice, itemId, houseIndex);
            }

            // ---- reprice existing ahbot listings on meaningful price moves ----
            // (probe orders below the reference follow the price too)
            static const uint32 PROBE_PCTS[5] = {85, 75, 65, 55, 45};
            auto aitr = ahbotListings.find(itemId);
            bool priceMoved = oldPrice && (uint32)std::abs((int64)newPrice - (int64)oldPrice) * 100 / oldPrice >= m_mmRepriceThreshold;
            if (state.price && aitr != ahbotListings.end() && (oldPrice == 0 || priceMoved))
            {
                for (AuctionEntry* auction : aitr->second)
                {
                    Item* item = sAuctionMgr.GetAItem(auction->itemGuidLow);
                    if (!item)
                        continue;
                    uint32 oldUnit = auction->buyout / std::max<uint32>(1, item->GetCount());
                    uint32 newUnit;
                    if (oldPrice && oldUnit < (uint64)oldPrice * 95 / 100)
                    {
                        // probe order: re-anchor to its probe level of the new price
                        int best = 0;
                        uint64 bestDiff = ~0ull;
                        for (int i = 0; i < 5; ++i)
                        {
                            uint64 target = (uint64)state.price * PROBE_PCTS[i] / 100;
                            uint64 diff = oldUnit > target ? oldUnit - target : target - oldUnit;
                            if (diff < bestDiff)
                            {
                                bestDiff = diff;
                                best = i;
                            }
                        }
                        newUnit = (uint32)(((uint64)state.price * PROBE_PCTS[best] + 50) / 100);
                    }
                    else
                    {
                        // main ladder: preserve the tier position in the new ladder
                        uint32 step = oldPrice ? GetLadderStep(oldPrice) : 1;
                        uint32 tier = oldPrice ? (uint32)(((uint64)oldUnit * 100 / oldPrice - 100) / step) : 0;
                        uint32 mainDepth = std::min<uint32>(MARKET_MAKER_MAX_LADDER, (50 / std::max<uint32>(1, GetLadderStep(state.price))) + 1);
                        if (tier >= mainDepth)
                            tier = mainDepth - 1;
                        newUnit = (uint32)(((uint64)state.price * (100 + tier * GetLadderStep(state.price)) + 50) / 100);
                    }
                    if (!newUnit)
                        newUnit = state.price;
                    uint32 newBuyout = newUnit * item->GetCount();
                    if (newBuyout && newBuyout != auction->buyout)
                    {
                        // keep bid/startbid within the buyout (no inverted bid > buyout)
                        if (auction->bid > newBuyout)
                            auction->bid = newBuyout;
                        // [2026-09-20] startbid used to be clamped DOWN only, so an upward reprice
                        // left the old (lower) startbid in place: after the epic value change
                        // 25%->50% every repriced epic showed startbid = 49% of buyout, while the
                        // creation path uses urand(Bid.Min, Bid.Max)% = 95..100%. Pull startbid back
                        // into that band; a listing already inside it is left untouched (no jitter
                        // on every reprice).
                        uint32 bidLo = (uint32)((uint64)newBuyout * m_auctionBidMin / 100);
                        uint32 bidHi = (uint32)((uint64)newBuyout * m_auctionBidMax / 100);
                        if (auction->startbid < bidLo || auction->startbid > bidHi)
                        {
                            uint32 target = (bidLo >= bidHi) ? bidHi : urand(bidLo, bidHi);
                            if (auction->bid && target > auction->bid)
                                target = auction->bid;   // never raise startbid above an existing bid
                            auction->startbid = target;
                        }
                        auction->buyout = newBuyout;
                        CharacterDatabase.PExecute("UPDATE auction SET buyoutprice = %u, lastbid = %u, startbid = %u WHERE id = %u", newBuyout, auction->bid, auction->startbid, auction->Id);
                    }
                }
            }

            // ---- own main-tier stock + probe stock for the next scan ----
            std::array<uint32, MARKET_MAKER_MAX_LADDER> nextTier = {};
            std::array<uint32, 5> nextProbe = {};
            if (state.price && aitr != ahbotListings.end())
            {
                for (AuctionEntry* auction : aitr->second)
                {
                    Item* item = sAuctionMgr.GetAItem(auction->itemGuidLow);
                    if (!item)
                        continue;
                    uint32 unit = auction->buyout / std::max<uint32>(1, item->GetCount());
                    if (unit < (uint64)state.price * 95 / 100)
                    {
                        // probe tier: nearest of 85/75/65/55/45%
                        int best = 0;
                        uint64 bestDiff = ~0ull;
                        for (int i = 0; i < 5; ++i)
                        {
                            uint64 target = (uint64)state.price * PROBE_PCTS[i] / 100;
                            uint64 diff = unit > target ? unit - target : target - unit;
                            if (diff < bestDiff)
                            {
                                bestDiff = diff;
                                best = i;
                            }
                        }
                        nextProbe[best] += item->GetCount();
                    }
                    else
                    {
                        uint32 tier = (uint32)(((uint64)unit * 100 / state.price - 100) / GetLadderStep(state.price));
                        if (tier < MARKET_MAKER_MAX_LADDER)
                            nextTier[tier] += item->GetCount();
                    }
                }
            }
            // (prevTierStock was snapshotted for all book states before the scan loop;
            // the per-item snapshot line moved there - see [booked-reset 2026-09-07])
            state.tierStock = nextTier;
            state.probeStock = nextProbe;
        }
    }
}

// Market-maker quote state for an item on a house (nullptr if no data yet)
AuctionHouseBotMarketState* AuctionHouseBot::GetMarketState(uint32 itemId, AuctionHouseType houseType)
{
    auto itr = m_marketState.find(itemId);
    if (itr == m_marketState.end())
        return nullptr;
    return &itr->second[houseType];
}

// Effective ladder step % for a price level: low-price items use smaller
// percentage steps so a tier jump stays meaningful. Pure percentage math;
// tier prices are rounded to integers at the call sites.
uint32 AuctionHouseBot::GetLadderStep(uint32 priceRef) const
{
    uint32 step = m_mmLadderStep;
    if (priceRef < 100)
        step = std::min(step, 5u);      // < 1s/unit: at most 5%
    else if (priceRef < 500)
        step = std::min(step, 10u);     // < 5s/unit: at most 10%
    else if (priceRef < 2000)
        step = std::min(step, 25u);     // < 20s/unit: at most 25%
    return step;
}

// Effective in-memory auction-map index a house action operates on: with linked
// auction houses every action collapses to the NEUTRAL map (the only one players
// ever see). Kept per-house on servers without cross-faction auctions.
uint32 AuctionHouseBot::EffectiveHouseIndex(uint32 houseType) const
{
    if (sWorld.getConfig(CONFIG_BOOL_ALLOW_TWO_SIDE_INTERACTION_AUCTION))
        return AUCTION_HOUSE_NEUTRAL;
    return houseType;
}

// Load the operator book (ahbot_market_state, house 2). [v2 2026-09-07] market-
// making scope is DATA-driven and nothing else: an item is a book member iff its
// operator row is enabled with category == 1. The old candidates/crafted/instance
// universe computation from world loot tables was removed - the static dev/055 SQL
// (computed offline: droppable class7 six-subclass universe minus crafted-only and
// instance-only sources) owns row creation, this loader only mirrors the rows.
void AuctionHouseBot::LoadCatalogOverrides()
{
    m_catalogUniverse.clear();
    m_catalogOverrides.clear();

    uint32 tAll = WorldTimer::getMSTime();
    // one pass: overrides + book set (category == 1 && enabled, house 2)
    if (auto result = CharacterDatabase.Query("SELECT item, MAX(enabled), MAX(target), MAX(capacity), MAX(category), MAX(price) FROM ahbot_market_state WHERE auction_house = 2 GROUP BY item"))
    {
        do
        {
            Field* fields = result->Fetch();
            AuctionHouseBotCatalogEntry e;
            e.enabled = fields[1].GetUInt32() != 0;
            e.target = fields[2].GetUInt32();
            e.capacity = fields[3].GetUInt32();
            e.category = fields[4].GetUInt32();
            e.price = fields[5].GetUInt32();
            uint32 itemId = fields[0].GetUInt32();
            m_catalogOverrides[itemId] = e;
            if (e.enabled && e.category == 1)
                m_catalogUniverse.insert(itemId);
        } while (result->NextRow());
    }
    m_catalogUniverseVec.assign(m_catalogUniverse.begin(), m_catalogUniverse.end());
    std::sort(m_catalogUniverseVec.begin(), m_catalogUniverseVec.end());
    sLog.outError("[AHBTIMER] catalog book(cat1+enabled)=%u overrides=%u took %ums",
                  (uint32)m_catalogUniverse.size(), (uint32)m_catalogOverrides.size(), WorldTimer::getMSTime() - tAll);
    sLog.outString("AHBot market-maker catalog: %u book items (%u operator overrides)", (uint32)m_catalogUniverse.size(), (uint32)m_catalogOverrides.size());
}

AuctionHouseBotCatalogEntry AuctionHouseBot::GetCatalogEntry(uint32 itemId) const
{
    AuctionHouseBotCatalogEntry e;
    auto itr = m_catalogOverrides.find(itemId);
    if (itr != m_catalogOverrides.end())
    {
        e.enabled = itr->second.enabled;
        e.target = itr->second.target;
        e.capacity = itr->second.capacity;
        e.category = itr->second.category;
        e.price = itr->second.price;
    }
    return e;
}

bool AuctionHouseBot::IsCatalogItem(uint32 itemId) const
{
    // [v2 2026-09-07] row-driven: an operator row (house 2) with category 1 (book)
    // or 2 (fixed vendor-price, reserved) and enabled. category 0 (untouched) and 3
    // (ban) are not catalog members; no-row items resolve to category 0 as well.
    AuctionHouseBotCatalogEntry e = GetCatalogEntry(itemId);
    return e.enabled && (e.category == 1 || e.category == 2);
}

// [v2 2026-09-07] strict operator-book membership used by the sell/buy MM gates:
// an ahbot_market_state row must EXIST for this item (house 2), be enabled and
// category == 1. Purely data-driven - no item class or loot-table computation.
bool AuctionHouseBot::IsMmBookItem(uint32 itemId) const
{
    auto itr = m_catalogOverrides.find(itemId);
    return itr != m_catalogOverrides.end() && itr->second.enabled && itr->second.category == 1;
}

bool AuctionHouseBot::IsTransitionItem(uint32 itemId) const
{
    // policy is legacy and folded into the unified table (category supersedes it);
    // only automated ItemLevel tiering remains.
    if (!m_transitionItemLevel)
        return false;
    ItemPrototype const* proto = ObjectMgr::GetItemPrototype(itemId);
    return proto && proto->ItemLevel <= m_transitionItemLevel;
}

uint32 AuctionHouseBot::GetCatalogFixedPrice(uint32 itemId) const
{
    AuctionHouseBotCatalogEntry e = GetCatalogEntry(itemId);
    return e.category == 2 ? e.price : 0;
}

uint32 AuctionHouseBot::GetBaselineTarget(uint32 itemId) const
{
    AuctionHouseBotCatalogEntry cat = GetCatalogEntry(itemId);
    uint32 base = cat.target ? cat.target : m_catalogTarget;
    if (IsTransitionItem(itemId))
        base = std::min<uint32>(m_catalogCapacity, (uint64)base * m_transitionTargetMult / 100);
    return base;
}

void AuctionHouseBot::EnsureTargets(AuctionHouseBotMarketState& state, uint32 itemId)
{
    if (state.target && state.capacity)
        return;
    AuctionHouseBotCatalogEntry cat = GetCatalogEntry(itemId);
    uint32 target = cat.target ? cat.target : m_catalogTarget;
    uint32 capacity = cat.capacity ? cat.capacity : m_catalogCapacity;
    if (!capacity)
        capacity = m_catalogCapacity;
    if (IsTransitionItem(itemId))
        target = std::min<uint32>(capacity, (uint64)target * m_transitionTargetMult / 100);
    state.target = target;
    state.capacity = capacity;
}

// Load the flow/ledger counters (ahbot_market_state). [v3 2026-09-07] the virtual
// inventory is abandoned: no qty init-to-target, no reconciliation against shelf
// lots. Only the gold/flow observables (spent/earned/flow_bought/flow_sold) are
// restored so price settlement and the operator log stay continuous across restarts.
void AuctionHouseBot::LoadInventory()
{
    if (auto result = CharacterDatabase.Query("SELECT item, auction_house, spent, earned, flow_bought, flow_sold, day_price, day_start, last_settle_time FROM ahbot_market_state"))
    {
        do
        {
            Field* fields = result->Fetch();
            uint32 itemId = fields[0].GetUInt32();
            uint32 house = fields[1].GetUInt32();
            if (house >= MAX_AUCTION_HOUSE_TYPE)
                continue;
            AuctionHouseBotMarketState& state = m_marketState[itemId][house];
            state.spentGold = fields[2].GetUInt32();
            state.earnedGold = fields[3].GetUInt32();
            state.flowBought = fields[4].GetUInt32();
            state.flowSold = fields[5].GetUInt32();
            // [2026-09-18] 报价每日限额窗口（day_price/day_start）
            state.dayPrice = fields[6].GetUInt32();
            state.dayStart = fields[7].GetUInt32();
            // [2026-09-21] 结算时钟同样持久化：原先只在内存 ⇒ 每次重启都会"提前结算一次"
            state.lastSettleTime = fields[8].GetUInt32();
        } while (result->NextRow());
    }

    // [2026-09-18] 熔断③（日预算）跨重启连续：读回 24h 窗口已释放的金币
    if (auto budget = CharacterDatabase.Query("SELECT day_start, gold_spent FROM ahbot_daily_budget WHERE id = 1"))
    {
        Field* f = budget->Fetch();
        m_dayGoldStart = f[0].GetUInt32();
        m_dayGoldSpent = f[1].GetUInt64();
        sLog.outError("[AHBOT] daily gold budget loaded: window_start=%u spent=%llu copper (%.0f gold), limit=%llu copper",
            m_dayGoldStart, (unsigned long long)m_dayGoldSpent, double(m_dayGoldSpent) / 10000.0,
            (unsigned long long)m_mmMaxGoldPerDay);
    }
}

// [2026-09-18] 熔断③：日预算窗口 —— 满 24h 重置（跨重启连续，持久化在 ahbot_daily_budget）
void AuctionHouseBot::RollDailyBudgetWindow()
{
    uint32 now = time(nullptr);
    if (m_dayGoldStart && now - m_dayGoldStart < 24 * HOUR)
        return;

    m_dayGoldStart = now;
    m_dayGoldSpent = 0;
    m_dayBreakerTripped = false;
    PersistDailyBudget();
    sLog.outError("[AHBOT] daily gold budget window ROLLED: new window starts %u, daily limit %llu copper (%.0f gold)",
        now, (unsigned long long)m_mmMaxGoldPerDay, double(m_mmMaxGoldPerDay) / 10000.0);
}

// [2026-09-18] 把日预算窗口落库（每次收购后调用一次；收购频率很低，开销可忽略）
void AuctionHouseBot::PersistDailyBudget()
{
    CharacterDatabase.PExecute("INSERT INTO ahbot_daily_budget (id, day_start, gold_spent) VALUES (1, %u, %llu) "
                               "ON DUPLICATE KEY UPDATE day_start = %u, gold_spent = %llu",
        m_dayGoldStart, (unsigned long long)m_dayGoldSpent,
        m_dayGoldStart, (unsigned long long)m_dayGoldSpent);
}

uint32 AuctionHouseBot::GetBookedUnits(AuctionHouseBotMarketState const& state) const
{
    uint32 booked = 0;
    for (uint32 t = 0; t < MARKET_MAKER_MAX_LADDER; ++t)
        booked += state.tierStock[t];
    for (uint32 p = 0; p < 5; ++p)
        booked += state.probeStock[p];
    return booked;
}

// A player bought one of our listings (or won it at expiry). [v3 2026-09-07] virtual
// inventory is gone: this only records the demand signal (flow_sold) and the gold the
// economy paid (earned) for the price machinery; nothing is deducted anywhere.
// goldReceived = final price paid (the gold the economy lost to our ask).
void AuctionHouseBot::DeductInventory(uint32 itemId, uint32 houseIdx, uint32 count, uint32 goldReceived, uint32 buyerGuid)
{
    if (houseIdx >= MAX_AUCTION_HOUSE_TYPE)
        return;
    AuctionHouseBotMarketState& state = m_marketState[itemId][houseIdx];
    state.earnedGold += goldReceived;
    state.flowSold += count; // central-bank flow signal: players consumed our supply
    // [2026-09-21] 记录本窗口内的不同买家（去重）：涨价要求 ≥2 个不同买家，
    // 单人自买自卖（"养价"）不能构成涨价依据。
    if (buyerGuid)
    {
        bool known = false;
        for (uint32 i = 0; i < state.soldBuyerCount; ++i)
            if (state.soldBuyers[i] == buyerGuid) { known = true; break; }
        if (!known && state.soldBuyerCount < state.soldBuyers.size())
            state.soldBuyers[state.soldBuyerCount++] = buyerGuid;
    }
    CharacterDatabase.PExecute("UPDATE ahbot_market_state SET earned = %u, flow_sold = %u WHERE item = %u AND auction_house = %u",
                               state.earnedGold, state.flowSold, itemId, houseIdx);
}

// The bot bought a player listing (buyout or won bid at expiry). [v3 2026-09-07] no
// stock is added anymore: only the supply signal (flow_bought) and gold created
// (spent) are recorded. goldPaid = final price (gold created into the economy).
void AuctionHouseBot::RecordBotPurchase(uint32 itemId, uint32 houseIdx, uint32 count, uint32 unitCost, uint32 goldPaid)
{
    if (houseIdx >= MAX_AUCTION_HOUSE_TYPE)
        return;
    // only operator book members (market_state category=1) are tracked in the ledger;
    // legacy (non-book) buyouts still settle but are NOT recorded.
    ItemPrototype const* buyProto = ObjectMgr::GetItemPrototype(itemId);
    if (!buyProto || !IsMmBookItem(itemId))
        return;
    AuctionHouseBotMarketState& state = m_marketState[itemId][houseIdx];
    state.spentGold += goldPaid;
    state.flowBought += count; // central-bank flow signal: players sold us supply
    CharacterDatabase.PExecute("UPDATE ahbot_market_state SET spent = %u, flow_bought = %u WHERE item = %u AND auction_house = %u",
                               state.spentGold, state.flowBought, itemId, houseIdx);
}

// (RefillCatalog removed in v3: no virtual inventory; QuoteCatalog mints straight to
// the exposure slice. m_catalogRotate is shared with QuoteCatalog.)

// Inventory-backed ladder quote for a rotating batch of catalog items. The book is
// topped up to the target exposure but only out of available holdings (inventory -
// booked), so a drained book stays drained until world supply refills - that is the
// bounded book that lets the eaten-tier check move the price. Probe orders below
// the reference also draw from holdings.
void AuctionHouseBot::QuoteCatalog(AuctionHouseObject* auctionHouse, uint32 houseIdx)
{
    if (m_catalogUniverseVec.empty())
        return;
    if (s_ahbotRebuildSuppressQuote)
        return;
    AuctionHouseType houseType = AuctionHouseType(houseIdx);
    AuctionHouseEntry const* houseEntry = sAuctionHouseStore.LookupEntry(houseIdx == AUCTION_HOUSE_ALLIANCE ? 1 : (houseIdx == AUCTION_HOUSE_HORDE ? 6 : 7));
    static const uint32 PROBE_PCTS[5] = {85, 75, 65, 55, 45};
    // tier volume weights: cheaper (deeper) tiers carry more of the book so a
    // sweep of tier 0 is a meaningful demand signal
    static const uint32 TIER_WEIGHTS[6] = {40, 25, 15, 10, 5, 5};

    uint32 batch = std::max<uint32>(1, m_catalogListBatch);
    uint32 done = 0;
    uint32 n = (uint32)m_catalogUniverseVec.size();

    // [booked-guard 2026-09-07] the "booked" (currently listed) count is refreshed
    // by the periodic market scan (UpdateMarketPrices). Between scans a stale
    // booked==0 would let every sell phase add the full exposure again, piling up
    // thousands of lots. If the last scan is older than 150s (or never ran), hold
    // all new quotes until the scan refreshes the snapshot.
    {
        uint32 now = time(nullptr);
        if (now > m_lastMarketUpdateTime + 150)
            return;
    }

    for (uint32 i = 0; i < n && done < batch; ++i)
    {
        uint32 itemId = m_catalogUniverseVec[(m_catalogRotate + i) % n];
        if (!IsCatalogItem(itemId))
            continue;
        ItemPrototype const* proto = ObjectMgr::GetItemPrototype(itemId);
        if (!proto || proto->GetMaxStackSize() == 0)
            continue;
        // category 2 (vendor-price good): quote anchored at the fixed row price; only a
        // single price tier (no ladder above, no probes below the fixed price). Inert
        // until rows are marked category 2 with a price (state.price is then forced to
        // the fixed price by UpdateMarketPrices as well).
        uint32 fixedUnit = GetCatalogFixedPrice(itemId);
        AuctionHouseBotMarketState* state = GetMarketState(itemId, houseType);
        if (!state)
            continue;
        EnsureTargets(*state, itemId);
        uint32 booked = GetBookedUnits(*state);
        // [v3 2026-09-07] no virtual inventory: the book is quoted straight to its
        // exposure slice (target x QuoteExposurePct) whenever booked falls below it -
        // supply is the market-maker mint, nothing else gates the quote.
        uint32 exposure = std::max<uint32>(1, (uint32)(((uint64)state->target * m_catalogExposurePct + 50) / 100));
        uint32 toList = exposure > booked ? exposure - booked : 0;
        if (!toList)
            continue;
        ++done;

        uint32 quotePrice = fixedUnit ? fixedUnit : state->price;
        if (!quotePrice)
        {
            // [MM-seed] book member without a market anchor yet (fresh row, price 0,
            // never scanned because it was never listed): seed the ladder from the
            // static valuation so the item is quoted instead of staying invisible.
            // UpdateMarketPrices takes over once it trades.
            ItemPrototype const* anchorProto = ObjectMgr::GetItemPrototype(itemId);
            if (anchorProto)
                quotePrice = CalculateBuyoutPrice(anchorProto);
            if (!quotePrice)
                continue;
            state->price = quotePrice;
            state->ref = quotePrice;
        }
        uint32 step = GetLadderStep(quotePrice);
        uint32 mainDepth = fixedUnit ? 1 : std::min<uint32>(MARKET_MAKER_MAX_LADDER, (50 / std::max<uint32>(1, step)) + 1);
        uint32 listedThisCycle = 0;

        // [group-listing 2026-09-05] stackable goods are packed into FULL stacks
        // (maxstack) so a handfull of rows carries the book instead of hundreds of
        // 1-unit tail lots. When not even one full stack is available we only keep a
        // single partial "presence" lot if nothing of the item is currently listed -
        // otherwise the units are held until they form a full stack (never invisible
        // while stocked, never spamming tiny rows).
        uint32 stackMax = std::max<uint32>(1, proto->GetMaxStackSize());
        uint32 remaining = toList;
        if (stackMax > 1)
        {
            uint32 wholeGroups = remaining / stackMax;
            if (wholeGroups == 0)
            {
                if (booked > 0)
                    continue;              // something is already listed; no tail-lot spam
                Item* partial = Item::CreateItem(itemId, std::min<uint32>(stackMax, remaining));
                if (!partial)
                    continue;
                uint32 buyoutPrice = (uint32)std::min<uint64>((uint64)quotePrice * partial->GetCount(), 2000000000ull);
                uint32 bidPrice = std::min(buyoutPrice, buyoutPrice * (urand(m_auctionBidMin, m_auctionBidMax)) / 100);
                auctionHouse->AddAuction(houseEntry, partial, urand(m_auctionTimeMin, m_auctionTimeMax) * HOUR, bidPrice, buyoutPrice);
                state->tierStock[0] += partial->GetCount();   // [booked-fix] immediate bookkeeping (see main tier below)
                listedThisCycle += partial->GetCount();
                (void)listedThisCycle;
                continue;                  // next catalog item
            }
            remaining = wholeGroups * stackMax;   // full stacks only
        }

        for (uint32 t = 0; t < mainDepth && remaining > 0; ++t)
        {
            uint32 weight = t < 6 ? TIER_WEIGHTS[t] : 2;
            uint32 tierUnits = (uint32)((uint64)remaining * weight / 100);
            if (tierUnits > remaining)
                tierUnits = remaining;
            // [group-listing] tier volume is a whole number of stacks
            if (stackMax > 1)
                tierUnits = (tierUnits / stackMax) * stackMax;
            if (!tierUnits)
                continue;
            uint32 unitPrice = (uint32)(((uint64)quotePrice * (100 + t * step) + 50) / 100);
            if (!unitPrice)
                continue;
            uint32 unitsLeft = tierUnits;
            while (unitsLeft > 0)
            {
                uint32 count = std::min<uint32>(stackMax, unitsLeft);
                uint32 buyoutPrice = (uint32)std::min<uint64>((uint64)unitPrice * count, 2000000000ull);
                Item* item = Item::CreateItem(itemId, count);
                if (!item)
                    break;
                uint32 bidPrice = std::min(buyoutPrice, buyoutPrice * (urand(m_auctionBidMin, m_auctionBidMax)) / 100);
                auctionHouse->AddAuction(houseEntry, item, urand(m_auctionTimeMin, m_auctionTimeMax) * HOUR, bidPrice, buyoutPrice);
                // [booked-fix 2026-09-07] count listed units into tierStock IMMEDIATELY
                // (same as the probe guard below). Without this the booked snapshot only
                // refreshes on the next 60s market scan, so every quote cycle inside the
                // scan window re-adds the full exposure on top of what is already listed -
                // high-value stackables (Void Crystal, Large Prismatic Shard) piled up
                // 300+ lots within an hour. The scan re-buckets tierStock from the real
                // shelf on its next pass, so this stays consistent.
                state->tierStock[t] += count;
                unitsLeft -= count;
                listedThisCycle += count;
                remaining -= count;
            }
        }
        (void)listedThisCycle;

        // probe order: one small sell order below the reference, placed only when
        // the current probe tier is empty and the cooldown elapsed. [v3] no inventory
        // check anymore (mint supply); fixed-price category-2 goods never probe below
        // their fixed price.
        if (!fixedUnit && m_mmProbeUnits && state->probeCooldown == 0)
        {
            uint32 level = std::min<uint32>(4, state->probeLevel);
            if (state->probeStock[level] < m_mmProbeUnits)
            {
                uint32 probeUnitPrice = (uint32)(((uint64)state->price * PROBE_PCTS[level] + 50) / 100);
                if (probeUnitPrice)
                {
                    uint32 probeCount = m_mmProbeUnits - state->probeStock[level];
                    Item* probeItem = Item::CreateItem(itemId, probeCount);
                    if (probeItem)
                    {
                        uint32 probeBuyout = (uint32)std::min<uint64>((uint64)probeUnitPrice * probeCount, 2000000000ull);
                        uint32 probeBid = std::min(probeBuyout, probeBuyout * (urand(m_auctionBidMin, m_auctionBidMax)) / 100);
                        auctionHouse->AddAuction(houseEntry, probeItem, urand(m_auctionTimeMin, m_auctionTimeMax) * HOUR, probeBid, probeBuyout);
                        // [probe-guard] mark tier filled immediately (see loot probe)
                        state->probeStock[level] += probeCount;
                    }
                }
            }
        }
    }
    m_catalogRotate = (m_catalogRotate + batch) % n;
}

bool AuctionHouseBot::ReloadAllConfig()
{
    Initialize();
    return true;
}

void AuctionHouseBot::Rebuild(bool all)
{
    sLog.outString("AHBot: Rebuilding auction house items");
    s_ahbotRebuildSuppressQuote = true; // expire-only: no quoting during the rapid Update() loop
    for (uint32 i = 0; i < MAX_AUCTION_HOUSE_TYPE; ++i)
    {
        AuctionHouseObject::AuctionEntryMapBounds bounds = sAuctionMgr.GetAuctionsMap(AuctionHouseType(i))->GetAuctionsBounds();
        for (AuctionHouseObject::AuctionEntryMap::const_iterator itr = bounds.first; itr != bounds.second; ++itr)
        {
            AuctionEntry* entry = itr->second;
            if (!entry->owner)
            {
                // ahbot auction
                if (all || entry->bid == 0) // expire auction if no bid or forced
                    entry->expireTime = sWorld.GetGameTime();
            }
        }
    }
    // refill auction house with items, simulating typical max amount of items available after some time
    uint32 updateCounter = std::min<uint32>(600, ((m_auctionTimeMax - m_auctionTimeMin) / 2 + m_auctionTimeMin) * 90);
    for (uint32 i = 0; i < updateCounter; ++i)
    {
        if (m_houseAction >= MAX_AUCTION_HOUSE_TYPE - 1)
            m_houseAction = -1; // this prevents AHBot from buying items when refilling
        Update();
    }
    s_ahbotRebuildSuppressQuote = false;
}

void AuctionHouseBot::PrepareStatusInfos(AuctionHouseBotStatusInfo& statusInfo) const
{
    for (uint32 i = 0; i < MAX_AUCTION_HOUSE_TYPE; ++i)
    {
        statusInfo[i].ItemsCount = 0;

        for (unsigned int& j : statusInfo[i].QualityInfo)
            j = 0;

        AuctionHouseObject::AuctionEntryMapBounds bounds = sAuctionMgr.GetAuctionsMap(AuctionHouseType(i))->GetAuctionsBounds();
        for (AuctionHouseObject::AuctionEntryMap::const_iterator itr = bounds.first; itr != bounds.second; ++itr)
        {
            AuctionEntry* entry = itr->second;
            if (Item* item = sAuctionMgr.GetAItem(entry->itemGuidLow))
            {
                ItemPrototype const* prototype = item->GetProto();
                if (!entry->owner)
                {
                    // count only ahbot auctions
                    if (prototype->Quality < MAX_ITEM_QUALITY)
                        ++statusInfo[i].QualityInfo[prototype->Quality];

                    ++statusInfo[i].ItemsCount;
                }
            }
        }
    }
}

void AuctionHouseBot::SetItemData(uint32 item, AuctionHouseBotItemData& itemData, bool reset)
{
    // ahbot_items is folded into ahbot_market_state keyed (item, auction_house).
    // The legacy .ahbot item command is item-global; canonicalize new overrides on
    // the auction_house=0 row while clearing stale values from every house row.
    CharacterDatabase.PExecute("UPDATE ahbot_market_state SET override_base_price = 0, override_add_chance = 0, override_min_amount = 0, override_max_amount = 0 WHERE item = %u", item);

    if (reset)
    {
        m_itemData.erase(item);
        return;
    }
    ItemPrototype const* prototype = ObjectMgr::GetItemPrototype(item);
    if (!prototype)
        return;

    if (itemData.AddChance > 100)
        itemData.AddChance = 100;

    if (itemData.MinAmount == 0)
        itemData.MinAmount = prototype->GetMaxStackSize();
    if (itemData.MaxAmount == 0)
        itemData.MaxAmount = prototype->GetMaxStackSize();
    if (itemData.MaxAmount < itemData.MinAmount)
        itemData.MaxAmount = itemData.MinAmount;

    m_itemData[item] = itemData;

    // [house-fix 2026-09-07] store item-wide overrides on the auction_house=2 row: the
    // only house Initialize() (override load) and LoadCatalogOverrides() read. They
    // used to go to the house=0 row, which nothing reads - .ahbot item overrides
    // (Value/AddChance/MinAmount/MaxAmount) silently vanished on the next restart.
    CharacterDatabase.PExecute("INSERT INTO ahbot_market_state (item, auction_house, override_base_price, override_add_chance, override_min_amount, override_max_amount, enabled, category, price, target, capacity) VALUES (%u, %u, %u, %u, %u, %u, 1, 1, 0, 500, 1500) AS new ON DUPLICATE KEY UPDATE override_base_price = new.override_base_price, override_add_chance = new.override_add_chance, override_min_amount = new.override_min_amount, override_max_amount = new.override_max_amount", item, 2, itemData.Value, itemData.AddChance, itemData.MinAmount, itemData.MaxAmount);
}

AuctionHouseBotItemData AuctionHouseBot::GetItemData(uint32 item)
{
    auto iterator = m_itemData.find(item);
    if (iterator != m_itemData.end())
        return iterator->second;

    // item data not overridden, set MinAmount/MaxAmount to 0 (those values can normally never be 0) as a means to alert requester that item data is not overridden
    AuctionHouseBotItemData itemData;
    ItemPrototype const* prototype = ObjectMgr::GetItemPrototype(item);
    itemData.Value = prototype ? CalculateBuyoutPrice(prototype) : 0;
    return itemData;
}

uint32 AuctionHouseBot::GetMinMaxConfig(const char* config, uint32 minValue, uint32 maxValue, uint32 defaultValue)
{
    uint32 field = m_ahBotCfg.GetIntDefault(config, defaultValue);
    if (field < minValue)
    {
        sLog.outError("AHBot error: %s must be between %u and %u. Setting value to %u.", config, minValue, maxValue, defaultValue);
        field = defaultValue;
    } else if (field > maxValue)
    {
        sLog.outError("AHBot error: %s must be between %u and %u. Setting value to %u.", config, minValue, maxValue, defaultValue);
        field = defaultValue;
    }
    return field;
}

void AuctionHouseBot::ParseLootConfig(char const* fieldname, std::vector<int32>& lootConfig)
{
    std::stringstream includeStream(m_ahBotCfg.GetStringDefault(fieldname));
    std::string temp;
    lootConfig.clear();
    while (getline(includeStream, temp, ','))
        lootConfig.push_back(atoi(temp.c_str()));
    if (lootConfig.size() > 4)
        sLog.outError("AHBot error: Too many values specified for field %s (%lu), 4 values required. Additional values ignored.", fieldname, lootConfig.size());
    else if (lootConfig.size() < 4)
    {
        sLog.outError("AHBot error: Too few values specified for field %s (%lu), 4 values required. Setting 0 for remaining values.", fieldname, lootConfig.size());
        while (lootConfig.size() < 4)
            lootConfig.push_back(0);
    }
    for (uint32 index = 1; index < 4; ++index)
    {
        if (lootConfig[index] < 0)
        {
            sLog.outError("AHBot error: %s value (%d) for field %s should not be a negative number, setting value to 0.", (index == 1 ? "Second" : (index == 2 ? "Third" : "Fourth")), lootConfig[index], fieldname);
            lootConfig[index] = 0;
        }
    }
    if (lootConfig[0] > lootConfig[1])
    {
        sLog.outError("AHBot error: First value (%d) must be less than or equal to second value (%d) for field %s. Setting first value to second value.", lootConfig[0], lootConfig[1], fieldname);
        lootConfig[0] = lootConfig[1];
    }
    if (lootConfig[2] > lootConfig[3])
    {
        sLog.outError("AHBot error: Third value (%d) must be less than or equal to fourth value (%d) for field %s. Setting third value to fourth value.", lootConfig[2], lootConfig[3], fieldname);
        lootConfig[2] = lootConfig[3];
    }
}

void AuctionHouseBot::FillUintVectorFromQuery(char const* query, std::vector<uint32>& lootTemplates)
{
    lootTemplates.clear();
    if (auto queryResult = WorldDatabase.PQuery("%s", query))
    {
        BarGoLink bar(queryResult->GetRowCount());
        do
        {
            bar.step();
            Field* fields = queryResult->Fetch();
            uint32 entry = fields[0].GetUInt32();
            if (!entry)
                continue;
            lootTemplates.push_back(fields[0].GetUInt32());
        } while (queryResult->NextRow());
    }
}

void AuctionHouseBot::ParseLevelConstraints()
{
    // Get settings from config
    m_useDynamicMaxLevel = m_ahBotCfg.GetBoolDefault("AuctionHouseBot.Level.DynamicMaxRequired", false);
    m_ignoreGm = m_ahBotCfg.GetBoolDefault("AuctionHouseBot.Level.IgnoreGmAccounts", false);
    m_levelRefreshInterval = m_ahBotCfg.GetIntDefault("AuctionHouseBot.Level.DynamicRefreshInterval", 10) * MINUTE;
    m_lastLevelUpdateTime = time(nullptr);
    m_maxRequiredLevel = GetMinMaxConfig("AuctionHouseBot.Level.MaxRequired", 1, STRONG_MAX_LEVEL, DEFAULT_MAX_LEVEL);

    if (m_useDynamicMaxLevel)
    {
	UpdateDynamicMaxLevel();
    }
    else
    {
	sLog.outString("AHBot Static max required level set to %u", m_maxRequiredLevel);
    }

    CalculateItemLevelCap();

    m_lastLevelUpdateTime = time(nullptr); // So we don't instantly recalc after startup
}

void AuctionHouseBot::UpdateDynamicMaxLevel()
{
    // Attempt to query all online characters ordered by level
    if (auto result = CharacterDatabase.PQuery("SELECT account, level FROM characters WHERE online = 1 ORDER BY level DESC"))
    {
	// Always grab the first result as fallback (highest overall)
	Field* firstRow = result->Fetch();
	uint32 firstAcct = firstRow[0].GetUInt32();
	uint32 fallbackLevel = firstRow[1].GetUInt32();
	m_maxRequiredLevel = fallbackLevel;

	if (m_ignoreGm)
	{
	    std::set<uint32> gmAccounts;
	    // Collect GM accounts
	    if (auto gmResult = LoginDatabase.PQuery("SELECT id FROM account WHERE gmlevel > 0"))
	    {
		do
		{
		    Field* field = gmResult->Fetch();
		    gmAccounts.insert(field[0].GetUInt32());
		} while (gmResult->NextRow());
	    }

            // Look for highest non-GM character
	    if (gmAccounts.count(firstAcct) == 0)
	    {
		sLog.outString("AHBot Dynamic max required level (excluding GMs) set to %u", fallbackLevel);
	    }
	    else
	    {
		bool foundNonGm = false;
		while (result->NextRow())
		{
		    Field* row = result->Fetch();
		    uint32 accId = row[0].GetUInt32();
		    uint32 level = row[1].GetUInt32();

		    if (gmAccounts.count(accId) == 0)
		    {
			m_maxRequiredLevel = level;
			foundNonGm = true;
			sLog.outString("AHBot Dynamic max required level (excluding GMs) set to %u", m_maxRequiredLevel);
			break;
		    }
		}

		if (!foundNonGm)
		{
		    sLog.outString("AHBot Notice: No non-GM players online. Fallback max required level (including GMs) set to %u", fallbackLevel);
		}
	    }
	}
	else
	{
	    sLog.outString("AHBot Dynamic max required level set to %u", m_maxRequiredLevel);
	}
    }
    else
    {
	sLog.outError("AHBot Error: No online characters found. Retaining static max required level %u", m_maxRequiredLevel);
    }
}

void AuctionHouseBot::CalculateItemLevelCap()
{
    if (m_maxRequiredLevel >= DEFAULT_MAX_LEVEL)
    {
        m_maxItemLevel = STRONG_MAX_LEVEL;
        sLog.outString("AHBot ItemLevel cap removed (set to %u) because max required level is >= %u.", STRONG_MAX_LEVEL, DEFAULT_MAX_LEVEL);
    }
    else
    {
        m_maxItemLevel = m_maxRequiredLevel + 5; // Typical item level is required level + 5
    }
}


void AuctionHouseBot::ParseItemValueConfig(char const* fieldname, std::vector<uint32>& itemValues)
{
    std::stringstream includeStream(m_ahBotCfg.GetStringDefault(fieldname));
    std::string temp;
    for (uint32 index = 0; getline(includeStream, temp, ','); ++index)
    {
        if (index < itemValues.size())
            itemValues[index] = atoi(temp.c_str());
    }
}

void AuctionHouseBot::AddLootToItemMap(LootStore* store, std::vector<int32>& lootConfig, std::vector<uint32>& lootTemplates, std::unordered_map<uint32, uint32>& itemMap)
{
    if (lootConfig[1] <= 0 || lootConfig[3] <= 0 || lootTemplates.empty())
        return;
    int32 maxTemplates = lootConfig[0] < 0 ? urand(0, lootConfig[1] - lootConfig[0]) + lootConfig[0] : urand(lootConfig[0], lootConfig[1]);
    if (maxTemplates <= 0)
        return;
    for (int32 templateCounter = 0; templateCounter < maxTemplates; ++templateCounter)
    {
        uint32 lootTemplate = urand(0, lootTemplates.size() - 1);
        LootTemplate const* lootTable = store->GetLootFor(lootTemplates[lootTemplate]);
        if (!lootTable)
            continue;
        std::unique_ptr<Loot> loot = std::make_unique<Loot>(LOOT_DEBUG);
        for (uint32 repeat = urand(lootConfig[2], lootConfig[3]); repeat > 0; --repeat)
            lootTable->Process(*loot, nullptr, store->IsRatesAllowed());

        LootItem* lootItem;
        for (uint32 slot = 0; (lootItem = loot->GetLootItemInSlot(slot)); ++slot)
	{
	    ItemPrototype const* prototype = sItemStorage.LookupEntry<ItemPrototype>(lootItem->itemId);
	    if (prototype && 
		(prototype->RequiredLevel > m_maxRequiredLevel ||
		 prototype->ItemLevel > m_maxItemLevel))
	        continue;

	    itemMap[lootItem->itemId] += lootItem->count;
	}
    }
}

uint32 AuctionHouseBot::GetItemValue(ItemPrototype const* prototype) const
{
    // subclass-level override has the highest priority (per item quality)
    auto itr = m_itemSubclassValue.find(std::make_pair(prototype->Class, prototype->SubClass));
    if (itr != m_itemSubclassValue.end() && itr->second[prototype->Quality] >= 0)
        return uint32(itr->second[prototype->Quality]);

    // vendor-sold items default to vendor price (prevent buy-low/sell-high)
    if (m_vendorValue && m_vendorItems.find(prototype->ItemId) != m_vendorItems.end())
    {
        // If this item's class/quality value is explicitly 0 (Value.<quality> = 0,
        // i.e. "filter this class+quality out of the AH"), keep it excluded instead
        // of forcing the vendor price (100) back in. A 0 in Value.<quality> must win
        // over the vendor override so e.g. white armor (class 4, Normal=0) stays off.
        if (m_itemValue[prototype->Quality][prototype->Class] == 0)
            return 0;
        return 100;
    }

    return m_itemValue[prototype->Quality][prototype->Class];
}

uint32 AuctionHouseBot::CalculateBuyoutPrice(ItemPrototype const* prototype)
{
    uint32 buyoutPrice = prototype->BuyPrice;
    // test whether we have a buy price or if buy price greatly exceed sell price (causes item to be valued too high, notably arrows/shells do this)
    // if using sell price then price must be multiplied by 4 if white or gray item, 5 if green or better to match expected buy price
    if (buyoutPrice == 0 || (prototype->SellPrice > 0 && buyoutPrice / prototype->SellPrice > 5))
        buyoutPrice = prototype->SellPrice * (prototype->Quality <= ITEM_QUALITY_NORMAL ? 4 : 5);
    // multiply buyoutPrice with item quality price percentage
    // if item is sold by a vendor and vendor value is forced, then multiply by 100 (setting vendor price)
    buyoutPrice *= GetItemValue(prototype);
    buyoutPrice /= 100; // since we multiplied with m_itemValue
    return buyoutPrice;
}
