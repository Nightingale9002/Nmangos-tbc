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

// Operator override for one catalog item (ahbot_catalog). target/capacity 0 mean
// "use the config default". enabled=0 removes the item from the curated universe.
// policy: 0 = auto tiering by ItemLevel, 1 = force market good (normal supply
// depth regulation), 2 = force transition good (abundant supply). Interface kept
// for operator marking; prices are NOT tiered (asymmetric flow handles welfare).
struct AuctionHouseBotCatalogEntry
{
    bool enabled = true;
    uint32 target = 0;
    uint32 capacity = 0;
    uint32 policy = 0;
};

// Maximum ladder depth for the market-maker quote ladder (config caps below this).
#define MARKET_MAKER_MAX_LADDER 16

// Market-maker quote state for one item on one auction house (no inventory simulation).
// price is the current quote anchor: sell ladder tiers are price*(1+tier*step) upward,
// the (hidden) buy cap is price*(1-buyDepth). price rises a tier when the current
// price tier is bought out, follows the market down smoothly, and declines slowly when
// idle. ref is the adaptive baseline (min of static price and market signals) that the
// idle decline targets. ahbot_price persists price (the day's closing quote).
struct AuctionHouseBotMarketState
{
    uint32 median = 0;                      // median per-unit buyout of all listings (market depth)
    uint32 price = 0;                       // current quote anchor (ladder base), persisted to ahbot_price
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
    // ---- virtual inventory ledger (persisted to ahbot_inventory) ----
    // qty = total units held by the bot (listed + reserve). Availability to list
    // = qty - booked (booked = tierStock + probeStock from the last scan). Listing
    // and unsold expiry do not change qty; player buys deduct, bot purchases and
    // world-supply refills add. spentGold/earnedGold give the operator the gold
    // regulation observable (net flow = spent - earned).
    uint32 inventory = 0;
    uint32 avgCost = 0;        // weighted average purchase unit cost (copper)
    uint32 spentGold = 0;      // gold paid out to players for bot purchases
    uint32 earnedGold = 0;     // gold received from players for bot sales
    // demand-responsive holding targets (seeded from catalog/config)
    uint32 target = 0;         // desired holdings; refill stops here
    uint32 capacity = 0;       // hard cap; buy room = capacity - inventory
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
        // inventory hooks (called from AuctionHouseMgr when an auction settles):
        // a player bought one of our listings (qty -= count) or the bot bought a
        // player listing / won its bid (qty += count, avg cost updated)
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
        // (ahbot_inventory): world-supply refills add, bot purchases add, player
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
        // load ahbot_catalog overrides + ahbot_inventory ledger from the DB
        void LoadCatalogOverrides();
        void LoadInventory();
        // resolved catalog entry for an item (override or config defaults)
        AuctionHouseBotCatalogEntry GetCatalogEntry(uint32 itemId) const;
        // true if the item is in the curated universe AND not disabled by override
        bool IsCatalogItem(uint32 itemId) const;
        // true if the item is a low-level transition good (locked price, abundant supply)
        bool IsTransitionItem(uint32 itemId) const;
        // transition-adjusted baseline holding target for an item
        uint32 GetBaselineTarget(uint32 itemId) const;
        // seed target/capacity for a state (transition goods get the multiplier)
        void EnsureTargets(AuctionHouseBotMarketState& state, uint32 itemId);
        // units currently listed by us for this state (tierStock + probeStock)
        uint32 GetBookedUnits(AuctionHouseBotMarketState const& state) const;
        // world supply: refill a rotating batch of catalog items toward target
        void RefillCatalog(uint32 houseIdx);
        // inventory-backed ladder quote + probe orders for a rotating catalog batch
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
        // ---- curated Class7 catalog + virtual inventory (market-maker supply) ----
        bool m_catalogEnabled = true;     // curated catalog drives Class7 supply
        uint32 m_catalogTarget = 50;      // default target holdings (units) per item
        uint32 m_catalogCapacity = 200;   // default capacity (units) per item
        uint32 m_catalogRefillPerCycle = 100; // units refilled per item per cycle
        uint32 m_catalogRefillBatch = 25; // catalog items refilled per cycle (rotation)
        uint32 m_catalogListBatch = 25;   // catalog items quoted per cycle (rotation)
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
        // tables at Initialize/reload); operators prune/tune via ahbot_catalog
        std::unordered_set<uint32> m_catalogUniverse;
        std::vector<uint32> m_catalogUniverseVec; // sorted, for batch rotation
        // item -> operator override (ahbot_catalog)
        std::unordered_map<uint32, AuctionHouseBotCatalogEntry> m_catalogOverrides;
        // item -> per auction house market-maker state
        std::unordered_map<uint32, std::array<AuctionHouseBotMarketState, MAX_AUCTION_HOUSE_TYPE>> m_marketState;
};

#define sAuctionHouseBot MaNGOS::Singleton<AuctionHouseBot>::Instance()

#endif
