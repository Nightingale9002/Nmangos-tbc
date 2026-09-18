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

#ifndef AUCTION_HOUSE_BOT_H
#define AUCTION_HOUSE_BOT_H

#include "AuctionHouse/AuctionHouseMgr.h"
#include "Config/Config.h"
#include "Entities/ItemPrototype.h"
#include "Globals/SharedDefines.h"
#include "Loot/LootMgr.h"
#include "Util/Util.h"
#include <array>
#include <deque>
#include <map>
#include <utility>

struct AuctionHouseBotItemData
{
    uint32 Value = 0;
    uint32 AddChance = 0;
    uint32 MinAmount = 0;
    uint32 MaxAmount = 0;
};

// Operator override for one catalog item (ahbot_market_state). target/capacity 0 mean
// "use the config default". enabled=0 removes the item from the curated universe.
// (The legacy policy column was folded away; category below supersedes it.)
//
// category (operator model):
//   0 = untouched: NOT in the market-maker book (no quote/refill/absorb); the
//       original loot-table flow supplies it again (chance-gated).
//   1 = market good: market-maker book with central-bank flow pricing (current
//       behavior for the curated universe). Default when no catalog row exists.
//   2 = low-level good: market-maker book, unit price FIXED at `price` (row is
//       pre-filled with the vendor SellPrice); abundant supply.
//   3 = never supplied by ahbot (ban): excluded from the market-maker book AND
//       from the loot-table flow, regardless of universe membership - explicit
//       operator-level ban for materials ahbot must not trade (instance-only
//       301+ mats such as Sunmote / Heart of Darkness, crafted goods, ...).
// price: category==2 fixed unit price (vendor SellPrice); 0 = unset (category 1
// keeps flow pricing driven by ahbot_market_state.price_ref).
struct AuctionHouseBotCatalogEntry
{
    bool enabled = true;
    uint32 target = 0;
    uint32 capacity = 0;
    uint32 category = 0;    // no operator row => category 0 (untouched / NOT a book member)
    uint32 price = 0;       // category==2 fixed unit price
};

// Maximum ladder depth for the market-maker quote ladder (config caps below this).
#define MARKET_MAKER_MAX_LADDER 16

// Market-maker quote state for one item on one auction house (no inventory simulation).
// price is the current quote anchor: sell ladder tiers are price*(1+tier*step) upward,
// the (hidden) buy cap is price*(1-buyDepth). price rises a tier when the current
// price tier is bought out, follows the market down smoothly, and declines slowly when
// idle. ref is the adaptive baseline (min of static price and market signals) that the
// idle decline targets. ahbot_market_state.price_ref persists price (the day's closing quote).
struct AuctionHouseBotMarketState
{
    uint32 median = 0;                      // median per-unit buyout of all listings (market depth)
    uint32 price = 0;                       // current quote anchor (ladder base), persisted to ahbot_market_state
    uint32 ref = 0;                         // adaptive baseline: min(static, market signals); idle decline target
    uint32 lastTradeEMA = 0;                // EMA-smoothed most recent player trade unit price
    uint32 playerBestAsk = 0;               // lowest player listing unit price (downward pressure)
    uint32 listingCount = 0;                // total listing count (market depth)
    uint32 soldUnits = 0;                   // player-bought units in the last scan window
    uint32 idleScans = 0;                   // consecutive scans with no player sales
    uint32 buyoutsThisCycle = 0;            // buy quota consumed this refresh cycle
    float deviation = 0.0f;                 // |median - price| / price (volatility reference)
    // own-listing units per MAIN ladder tier (100%..150% of price, index = tier)
    std::array<uint32, MARKET_MAKER_MAX_LADDER> tierStock = {};
    std::array<uint32, MARKET_MAKER_MAX_LADDER> prevTierStock = {};
    // probe order state: one small sell order placed at a time below the reference
    // (90% -> 80% -> 70% -> 60% -> 50% of price), advancing one tier per below-quote
    // sale; probeStock[probeLevel] = own units on the current probe tier
    std::array<uint32, 5> probeStock = {};
    uint32 probeLevel = 0;        // 0=90%, 1=80%, 2=70%, 3=60%, 4=50%
    uint32 probeCooldown = 0;     // scans to wait before placing the next probe
    // rolling recent trade log (unit price, qty) - seed for future price-curve feature
    std::deque<std::pair<uint32, uint32>> tradeLog;
    // [v3 2026-09-07] virtual inventory is ABANDONED: no inventory/avgCost fields, no
    // qty ledger semantics. The book is quoted straight to its exposure slice and
    // supply is the market-maker mint, so restarts/expiries cannot corrupt a stock
    // count. spentGold/earnedGold/flow* remain as gold-regulation observables
    // (persisted in ahbot_market_state) feeding the price machinery.
    uint32 spentGold = 0;      // gold paid out to players for bot purchases
    uint32 earnedGold = 0;     // gold received from players for bot sales
    // quote exposure driver (seeded from catalog/config / static 055 rows)
    uint32 target = 0;         // desired concurrent exposure = target x QuoteExposurePct
    uint32 capacity = 0;       // (reserved; kept for the DB row mirror)
    // ---- central-bank price discovery ----
    // The fair value is UNKNOWN and is discovered from the bot's own order-flow
    // imbalance over a LONG settle period (default 24h, persisted so it survives
    // restarts). Price stability first: the anchor moves at most FlowMovePct once
    // per settle period, only when the flow is clearly one-sided:
    //   flowBought >> flowSold -> players flooded us with supply -> price too high
    //   flowSold   >> flowBought -> players consumed our supply -> price too low
    // balanced/quiet -> the price holds. Quantity (supply injected vs absorbed) is
    // regulated every scan by PLAYER LISTING DEPTH, never by the price.
    uint32 flowBought = 0;        // units the bot bought from players since last settle (persisted)
    uint32 flowSold = 0;          // units players bought from the bot since last settle (persisted)
    uint32 lastSettleTime = 0;    // time of the last flow settlement (price anchor move)
    uint32 probeDemandLevel = 0xFF; // deepest probe level (0=85% .. 4=45%) with a sale (observation)
    uint32 probeStaleScans = 0;     // scans since the last probe outcome (evidence decay)
    // [2026-09-18] 报价"每日上下移动限额"窗口：dayPrice = 本窗口开始时的报价，
    // dayStart = 窗口起始时间戳。窗口内报价被夹在 dayPrice ± MaxDailyMovePct 之间，
    // 满 24h 后窗口重置。两个值都持久化在 ahbot_market_state（day_price / day_start）。
    uint32 dayPrice = 0;
    uint32 dayStart = 0;
};

struct AuctionHouseBotStatusInfoPerType
{
    uint32 ItemsCount;
    uint32 QualityInfo[MAX_ITEM_QUALITY];
};

typedef AuctionHouseBotStatusInfoPerType AuctionHouseBotStatusInfo[MAX_AUCTION_HOUSE_TYPE];

class AuctionHouseBot
{
    public:
        AuctionHouseBot();
        ~AuctionHouseBot();

        void Initialize();
        void SetConfigFileName(const std::string& filename) { m_configFileName = filename; }
        void Update();

        // Following methods are mainly used by level3.cpp for ingame/console commands
        bool ReloadAllConfig();
        void Rebuild(bool all);
        void PrepareStatusInfos(AuctionHouseBotStatusInfo& statusInfo) const;
        void SetItemData(uint32 item, AuctionHouseBotItemData& itemData, bool reset = false);
        AuctionHouseBotItemData GetItemData(uint32 item);
        // real market quote state for an item on a house, nullptr if no data
        AuctionHouseBotMarketState* GetMarketState(uint32 itemId, AuctionHouseType houseType);
        // hidden buy depth % (for the quote command display)
        uint32 GetBuyDepth() const { return m_mmBuyDepth; }
        // concurrent listing exposure % of target (v3: the book quotes straight to it)
        uint32 GetExposurePct() const { return m_catalogExposurePct; }
        // flow hooks (called from AuctionHouseMgr when an auction settles; v3 keeps
        // only the demand/supply signals + gold observables, no stock movement):
        // a player bought one of our listings (flow_sold/earned) or the bot bought a
        // player listing / won its bid (flow_bought/spent)
        void DeductInventory(uint32 itemId, uint32 houseIdx, uint32 count, uint32 goldReceived);
        void RecordBotPurchase(uint32 itemId, uint32 houseIdx, uint32 count, uint32 unitCost, uint32 goldPaid);

    private:
        uint32 GetMinMaxConfig(const char* config, uint32 minValue, uint32 maxValue, uint32 defaultValue);
        void ParseLootConfig(char const* fieldname, std::vector<int32>& lootConfig);
        void FillUintVectorFromQuery(char const* query, std::vector<uint32>& lootTemplates);
	void ParseLevelConstraints();
	void UpdateDynamicMaxLevel();
        void CalculateItemLevelCap();
        void ParseItemValueConfig(char const* fieldname, std::vector<uint32>& itemValues);
        void AddLootToItemMap(LootStore* store, std::vector<int32>& lootConfig, std::vector<uint32>& lootTemplates, std::unordered_map<uint32, uint32>& itemMap);
        uint32 CalculateBuyoutPrice(ItemPrototype const* prototype);
        uint32 GetItemValue(ItemPrototype const* prototype) const;
        uint32 ValueWithVariance(uint32 itemValue) { return (uint32) (itemValue + ((int32) urand(0, m_valueVariance * 2 + 1) - (int32) m_valueVariance) * (int32) (itemValue / 100)); };

        // ---- market-maker ladder quoting ----
        // Tracks the real per-unit market price and quotes a sell ladder around it,
        // with a hidden bid cap below the market. Inventory is a virtual ledger
        // (ahbot_market_state): world-supply refills add, bot purchases add, player
        // buys of our listings deduct; availability to list = inventory - booked.
        void UpdateMarketPrices();
        // effective ladder step % for a price level: low-price items use smaller
        // steps (and always at least 1 copper per tier)
        uint32 GetLadderStep(uint32 priceRef) const;
        // the in-memory auction-map index a house action actually operates on:
        // with linked auction houses (AllowTwoSide.Interaction.Auction=1) all
        // visible activity collapses to the NEUTRAL map - routing adds/scans to
        // the faction maps would create listings players cannot see
        uint32 EffectiveHouseIndex(uint32 houseType) const;
        // load ahbot_market_state catalog/inventory/overrides from the DB
        void LoadCatalogOverrides();
        void LoadInventory();
        // resolved catalog entry for an item (override or config defaults)
        AuctionHouseBotCatalogEntry GetCatalogEntry(uint32 itemId) const;
        // true if the item is in the curated universe AND not disabled by override
        // (category 0 = untouched -> NOT a book member)
        bool IsCatalogItem(uint32 itemId) const;
        // [v2 2026-09-07] market-making scope is DATA-driven: an item is a book member
        // only when it has an operator row (ahbot_market_state, house 2) with
        // category == 1 (enabled). No hard-coded item class decides market-making
        // scope. (Unlike GetCatalogEntry - whose no-row default category is 0 - this
        // first requires the row to EXIST.)
        bool IsMmBookItem(uint32 itemId) const;
        // true if the item is a low-level transition good (abundant supply)
        bool IsTransitionItem(uint32 itemId) const;
        // fixed unit price of a category-2 (vendor-price) good; 0 unless the item is
        // marked category 2 with a price row (architecture: inert until marked)
        uint32 GetCatalogFixedPrice(uint32 itemId) const;
        // transition-adjusted baseline holding target for an item
        uint32 GetBaselineTarget(uint32 itemId) const;
        // seed target/capacity for a state (transition goods get the multiplier)
        void EnsureTargets(AuctionHouseBotMarketState& state, uint32 itemId);
        // units currently listed by us for this state (tierStock + probeStock)
        uint32 GetBookedUnits(AuctionHouseBotMarketState const& state) const;
        // [v3] exposure-slice ladder quote + probe orders for a rotating catalog batch
        // (virtual inventory removed; RefillCatalog deleted)
        void QuoteCatalog(AuctionHouseObject* auctionHouse, uint32 houseIdx);

        std::string m_configFileName;
        Config m_ahBotCfg;

        uint32 m_houseAction;

        uint32 m_chanceSell;
        uint32 m_chanceBuy;

        std::vector<int32> m_creatureLootNormalConfig;
        std::vector<int32> m_creatureLootRareConfig;
        std::vector<int32> m_creatureLootEliteConfig;
        std::vector<int32> m_creatureLootRareEliteConfig;
        std::vector<int32> m_creatureLootWorldBossConfig;
        std::vector<int32> m_disenchantLootConfig;
        std::vector<int32> m_fishingLootConfig;
        std::vector<int32> m_gameobjectLootConfig;
        std::vector<int32> m_skinningLootConfig;
        std::vector<int32> m_itemLootConfig;
        std::vector<int32> m_professionItemsConfig;

	bool m_useDynamicMaxLevel;
	bool m_ignoreGm;
	uint32 m_lastLevelUpdateTime = 0;
	uint32 m_levelRefreshInterval = 0;
	uint32 m_maxRequiredLevel;
	uint32 m_maxItemLevel;

        std::vector<std::vector<uint32>> m_itemValue = std::vector<std::vector<uint32>>(MAX_ITEM_QUALITY, std::vector<uint32>(MAX_ITEM_CLASS));
        std::map<std::pair<uint32, uint32>, std::array<int32, MAX_ITEM_QUALITY>> m_itemSubclassValue;
        bool m_vendorValue;
        uint32 m_valueVariance;
        uint32 m_auctionBidMin;
        uint32 m_auctionBidMax;
        uint32 m_auctionTimeMin;
        uint32 m_auctionTimeMax;
        uint32 m_buyValue;

        std::vector<uint32> m_creatureLootNormalTemplates;
        std::vector<uint32> m_creatureLootRareTemplates;
        std::vector<uint32> m_creatureLootEliteTemplates;
        std::vector<uint32> m_creatureLootRareEliteTemplates;
        std::vector<uint32> m_creatureLootWorldBossTemplates;
        std::vector<uint32> m_disenchantLootTemplates;
        std::vector<uint32> m_fishingLootTemplates;
        std::vector<uint32> m_gameobjectLootTemplates;
        std::vector<uint32> m_skinningLootTemplates;
        std::vector<uint32> m_itemLootTemplates;
        std::vector<uint32> m_professionItems;

        std::unordered_set<uint32> m_vendorItems;

        std::unordered_map<uint32, AuctionHouseBotItemData> m_itemData;

        // ---- market-maker ladder quote state ----
        bool m_marketEnabled = false;
        uint32 m_marketRefresh = 60;
        uint32 m_mmLadderStep = 1;        // sell ladder tier spacing % (e.g. 1% = 10 tiers of 1% up to 10% depth)
        uint32 m_mmLadderDepth = 10;      // number of ladder tiers (each tier carries 100/depth % of volume)
        uint32 m_mmBuyDepth = 10;         // hidden buy cap = price * (100 - BuyDepth) / 100
        uint32 m_mmBuyPerCycle = 0;       // max buyout units per item per refresh cycle (0 = unlimited)
        // [2026-09-18] 熔断②：每个刷新周期【全局】最多释放多少金币（铜）。0 = 不限制。
        // 起因：云端实测 bot 一次从玩家手里吃下 1218 个大块棱光碎片、释放 11,394 金
        // （净投放 11,905 金进经济），而原来只限额"件数/项"，没有任何金币总闸。
        uint64 m_mmMaxGoldPerCycle = 0;
        uint64 m_cycleGoldSpent = 0;      // 本周期已释放的金币（每次 Update 周期开始时清零）
        bool m_cycleBreakerTripped = false; // 本周期的熔断是否已触发（只记一次日志）
        // [2026-09-18] 熔断③（主闸，站长定案）：每 **24 小时** 全局最多释放多少金币（铜）。
        //   目标规模 50 人在线；在线时间不均匀 → 用"天"做硬限制，而不是"周期"。
        //   硬上限 5000 金/天（= 50000000 铜）。跨重启连续（持久化在 ahbot_daily_budget 表），
        //   否则每晚重启会把预算重置 → 等于没有闸。
        //   站长口径：真有人找到漏洞钻，那也算他的奖励，所以不设更多限制。
        uint64 m_mmMaxGoldPerDay = 0;
        uint64 m_dayGoldSpent = 0;        // 本 24h 窗口已释放的金币
        uint32 m_dayGoldStart = 0;        // 本窗口起点（unix）
        bool m_dayBreakerTripped = false; // 本窗口是否已触发熔断（只记一次日志）
        void RollDailyBudgetWindow();     // 窗口滚动（满 24h 重置）
        void PersistDailyBudget();        // 落库（跨重启连续）
        // [2026-09-18] 报价每日上下移动限额（百分比，0 = 不限制）。窗口 24h，见 state.dayPrice/dayStart。
        uint32 m_mmMaxDailyMovePct = 0;
        bool m_mmBidOnlyBuyout = true;   // only buyout player listings (bot bidding is free
                                         // - UpdateBid with no bidder mints gold to the seller)
        uint32 m_mmSmoothing = 50;        // EMA alpha % for following trade prices
        uint32 m_mmIdleThreshold = 60;    // consecutive scans with no sales before idle decline starts
        uint32 m_mmIdleDecay = 5;         // idle decline per scan in per-mille (5 = 0.5%)
        uint32 m_mmRepriceThreshold = 1;  // % price move that triggers repricing that item's existing listings
        uint32 m_mmMaxItemUnits = 200;    // cap on ahbot's own MAIN ladder units per item+house (bounded book)
        uint32 m_mmEatRatio = 50;         // % of the price tier sold in one window that counts as "bought out"
        uint32 m_mmProbeUnits = 5;        // units per probe sell order below the reference
        uint32 m_mmProbeInterval = 30;    // scans to wait between probe placements (probe one tier at a time)
        uint32 m_mmPriceFloor = 5;        // hard price floor as % of original static price
        uint32 m_mmPriceCeil = 300;       // hard price cap as % of original static price
        uint32 m_lastMarketUpdateTime = 0;
        // ---- curated catalog book (v3: exposure-slice quoting, no virtual inventory) ----
        bool m_catalogEnabled = true;     // curated catalog drives book supply
        uint32 m_catalogTarget = 50;      // default target exposure driver (units) per item
        uint32 m_catalogCapacity = 200;   // (reserved; kept for row mirror)
        uint32 m_catalogListBatch = 25;   // catalog items quoted per cycle (rotation)
        uint32 m_catalogExposurePct = 25; // % of target listed concurrently (rest stays stocked)
        uint32 m_catalogDemandBoostPct = 50; // target boost % when the price tier is eaten
        uint32 m_catalogIdleDecayPct = 5; // target decay % per idle scan after threshold
        uint32 m_catalogRotate = 0;       // rotating cursor for batch cycles
        // ---- central-bank flow price discovery (long settle period) ----
        uint32 m_flowRatio = 150;       // imbalance threshold %: bought>sold*1.5 => lower, sold>bought*1.5 => raise
        uint32 m_flowMoveDownPct = 5;   // anchor move % per settle when OVERPRICED (players flood us -> lower fast)
        uint32 m_flowMoveUpPct = 1;     // anchor move % per settle when UNDERPRICED (raise very slowly - welfare protection)
        uint32 m_flowMinUnits = 20;     // min total flow units in a period before the signal counts
        uint32 m_flowSettleHours = 24;  // settle period in hours (e.g. 24 = daily, 168 = weekly)
        // ---- player-listing-depth supply regulation (every scan) ----
        uint32 m_depthHighPct = 200;    // player supply >= target*2 -> shrink our injection (step down)
        uint32 m_depthLowPct = 50;      // player supply <= target*0.5 -> expand our injection (step up)
        uint32 m_depthStepPct = 5;      // target move % per scan toward the depth-driven direction
        // ---- item tiering (welfare supply) ----
        // Low-level old-world materials are transition goods: players rarely farm
        // them, so the bot is their only supplier. They get ABUNDANT supply
        // (target x TransitionTargetMult) so leveling is never starved. Prices are
        // NOT tiered - the asymmetric flow move (up 1% / down 5%) already keeps
        // price rises gentle for every good.
        uint32 m_transitionItemLevel = 40;  // ItemLevel <= this => transition good (0 = tiering off)
        uint32 m_transitionTargetMult = 3;  // transition goods hold target x this (abundant supply)
        // the curated universe: droppable + priceable Class 7 items (from world loot
        // tables at Initialize/reload); operators prune/tune via ahbot_market_state
        std::unordered_set<uint32> m_catalogUniverse;
        std::vector<uint32> m_catalogUniverseVec; // sorted, for batch rotation
        // item -> operator override (ahbot_market_state)
        std::unordered_map<uint32, AuctionHouseBotCatalogEntry> m_catalogOverrides;
        // item -> per auction house market-maker state
        std::unordered_map<uint32, std::array<AuctionHouseBotMarketState, MAX_AUCTION_HOUSE_TYPE>> m_marketState;
};

#define sAuctionHouseBot MaNGOS::Singleton<AuctionHouseBot>::Instance()

#endif
