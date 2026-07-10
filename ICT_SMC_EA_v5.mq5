//+------------------------------------------------------------------+
//|               INSTITUTIONAL ALPHA ENGINE v5.1 (MQL5)              |
//|           ICT/SMC Kill Zone + Mean Reversion Strategy            |
//+------------------------------------------------------------------+
//|  Engine 1: SMC Kill Zone (London 08-11 UK / NY 08-11 EST)      |
//|  Engine 2: Mean Reversion (Asian Session)                        |
//|                                                                  |
//|  Features:                                                       |
//|  - Order Block Detection with Age/Freshness Filter                |
//|  - Fair Value Gap (FVG) Detection                               |
//|  - Displacement Detection                                        |
//|  - Breaker Block Detection                                       |
//|  - Volume Absorption Check                                       |
//|  - Session Momentum Filter                                       |
//|  - DXY Correlation Guard                                        |
//|  - Volume Profile                                               |
//|  - VIX Cap                                                      |
//|  - Neural Feedback System                                        |
//+------------------------------------------------------------------+
#property copyright "ICT/SMC Institutional Trader"
#property link      "https://github.com/mostakimnasim5/Trading"
#property version   "5.1"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

// ── Connection ──────────────────────────────────────────────────────
input group "Connection"
string   InpSymbol     = "EURUSD";          // Trading Symbol
ulong     InpMagic     = 20260051;          // EA Magic Number
int       InpGMT       = 0;                 // Broker GMT Offset (0=UTC)

// ── Session Timing (DST-AWARE) ──────────────────────────────────────
input group "Session Timing"
int       InpLondonStartUK = 8;             // London KZ Start (UK Time)
int       InpLondonEndUK   = 11;            // London KZ End (UK Time)
int       InpNYStartEST    = 8;             // NY KZ Start (EST)
int       InpNYEndEST      = 11;            // NY KZ End (EST)
int       InpAsiaOpen      = 0;             // Asian Session Open (UTC)
int       InpAsiaRangeHrs  = 4;             // Hours to Build Asia Box
int       InpDeadZoneStart  = 20;            // Dead Zone Start (UTC)
int       InpSessionMomBars = 6;             // Session Momentum Bars (M5)

// ── Engine 1: SMC Core ──────────────────────────────────────────────
input group "Engine 1: SMC Kill Zone"
int       InpOBLookback      = 50;           // Order Block Lookback
int       InpOBMinAgeBars    = 3;            // OB Minimum Age (bars)
int       InpOBMaxAgeBars    = 20;           // OB Maximum Age (bars)
double    InpOBBuffPips      = 10.0;         // OB Price Buffer (pips)
double    InpOBMinStrength   = 50.0;         // OB Minimum Strength (%)
double    InpFVGMinPips     = 2.0;           // FVG Minimum (pips)
int       InpFVGMaxAge      = 10;            // FVG Maximum Age (bars)
int       InpMinConfirm     = 4;             // Min Confirmations (of 5)
double    InpVolSpikeMult   = 1.5;           // Volume Spike Multiplier
int       InpADXPeriod      = 14;            // ADX Period
double    InpADXMin         = 25.0;         // ADX Minimum
double    InpADXStrong      = 35.0;         // ADX Strong Trend
int       InpRSIPeriod      = 14;            // RSI Period
int       InpMACDFast        = 12;            // MACD Fast
int       InpMACDSlow        = 26;            // MACD Slow
int       InpMACDSignal      = 9;             // MACD Signal
double    InpATRSLMult      = 1.5;           // ATR SL Multiplier
double    InpTP1RR          = 2.0;           // TP1 Risk:Reward
double    InpTP2RR          = 3.0;           // TP2 Risk:Reward

// ── ICT Concepts (NEW) ───────────────────────────────────────────
input group "ICT Concepts"
bool      InpUseDisplacement   = true;        // Enable Displacement Detection
int       InpDispLookback      = 20;           // Displacement Lookback
int       InpDispMinBars      = 2;            // Min Bars to Engulf
double    InpDispVolMult      = 1.5;          // Volume Multiplier
bool      InpUseBreakerBlock  = true;         // Enable Breaker Block
int       InpBBLookback       = 30;           // Breaker Block Lookback
bool      InpUseAbsorption    = true;         // Enable Volume Absorption
int       InpAbsLookback      = 20;           // Absorption Lookback
double    InpAbsVolMult       = 2.0;          // Absorption Volume Mult

// ── Alpha Filters ─────────────────────────────────────────────────
input group "Alpha Filters"
bool      InpUseDXY         = true;            // Enable DXY Correlation
string    InpDXYSymbol     = "DXY";            // DXY Symbol
int       InpDXYLookback   = 20;              // DXY Lookback
bool      InpUseVP         = true;            // Enable Volume Profile
int       InpVPBars        = 100;             // VP Bars
int       InpVPBuckets     = 50;              // VP Buckets
double    InpVPValueArea   = 70.0;            // Value Area %
bool      InpUseVIX        = true;            // Enable VIX Cap
string    InpVIXSymbol     = "VIX";           // VIX Symbol
double    InpVIXMax       = 25.0;            // VIX Maximum Level
double    InpVIXCaution   = 20.0;            // VIX Caution Level

// ── Engine 2: Mean Reversion ──────────────────────────────────────
input group "Engine 2: Mean Reversion"
int       InpE2BBPeriod    = 20;              // Bollinger Period
double    InpE2BBStdDev   = 2.5;             // Bollinger StdDev
double    InpE2RSIOB      = 65.0;            // RSI Overbought
double    InpE2RSIOS       = 35.0;           // RSI Oversold
double    InpE2MinRange   = 25.0;            // Min Asia Range (pips)
double    InpE2SweepPips  = 2.0;            // Sweep Minimum (pips)
int       InpE2RejBars    = 5;               // Rejection Bars
int       InpE2PinbarPct  = 50;              // Pinbar Wick %
double    InpE2VolExhaust  = 0.85;            // Volume Exhaustion
double    InpE2TPMin      = 8.0;             // TP Minimum (pips)
double    InpE2TPMax      = 15.0;            // TP Maximum (pips)

// ── Risk Management ───────────────────────────────────────────────
input group "Risk Management"
double    InpRiskPct      = 1.0;             // Risk % (E1)
double    InpFixedLot     = 0.01;            // Fixed Lot (E2)
double    InpMaxSpread     = 1.5;             // Max Spread (pips)
double    InpMaxSpreadE2  = 2.5;            // Max Spread E2 (pips)
int       InpMaxTrades    = 1;               // Max Global Trades
int       InpMaxSlippage = 3;               // Max Slippage
double    InpBETiggerE2   = 10.0;            // BE Trigger (pips)
double    InpBEBuffer      = 0.5;             // BE Buffer (pips)
int       InpBETiggerE1   = 100;             // BE Trigger Points (E1)
int       InpBEBufferE1   = 5;               // BE Buffer Pips (E1)
double    InpPartialPct    = 50.0;            // Partial Close %
double    InpTrailATR     = 0.75;            // Trailing ATR Mult

// ── Neural Feedback ────────────────────────────────────────────────
input group "Neural Feedback"
int       InpNFMemory     = 50;              // Trade Memory
double    InpNFMinAcc     = 65.0;           // Min Accuracy %
int       InpNFPauseMins  = 120;            // Pause Minutes

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

// State
enum ENUM_ENGINE_STATE { ENGINE_KILLZONE, ENGINE_OFFZONE, ENGINE_DEAD };
enum ENUM_MARKET_BIAS  { BIAS_BULL, BIAS_BEAR, BIAS_RANGE };
enum ENUM_TRADE_DIR    { DIR_NONE, DIR_BUY, DIR_SELL };
enum ENUM_FILTER_FAIL  { FAIL_PASS, FAIL_KILLZONE, FAIL_SMC, FAIL_DXY, 
                         FAIL_DELTA, FAIL_VP, FAIL_VIX, FAIL_SPREAD, 
                         FAIL_OB, FAIL_FVG, FAIL_DISP, FAIL_BREAKER, FAIL_LOWRR };

ENUM_ENGINE_STATE gEngineState = ENGINE_DEAD;
ENUM_MARKET_BIAS   gBias = BIAS_RANGE;
datetime           gLastTradeTime = 0;
int                 gTicket = 0;

// Engine Results
struct SMCResult {
    bool              fired;
    ENUM_TRADE_DIR    direction;
    ENUM_FILTER_FAIL  blockReason;
    
    // SMC Pillars
    int               smcScore;
    bool              hasOB;
    bool              hasFVG;
    bool              hasVolSpike;
    bool              hasDivergence;
    bool              hasADX;
    bool              hasLiqSweep;
    double            obStrength;
    int               obAgeBars;
    bool              obIsFresh;
    
    // ICT Concepts
    bool              hasDisplacement;
    bool              hasBreakerBlock;
    bool              hasAbsorption;
    bool              hasSessionMomentum;
    double            dispPips;
    int               dispBars;
    double            breakerStrength;
    double            absRatio;
    double            momentumStrength;
    ENUM_TRADE_DIR    momentumDir;
    
    // Filters
    bool              inKillZone;
    string            killZoneType;
    bool              dxyConfirmed;
    bool              deltaPositive;
    bool              vpZoneValid;
    bool              vixClear;
    double            vixLevel;
    
    // Levels
    double            confidence;
    double            adxValue;
    double            spreadPips;
    double            slPrice;
    double            tp1Price;
    double            tp2Price;
    double            vpPOC;
    double            vpVAH;
    double            vpVAL;
};

struct RevResult {
    bool              fired;
    ENUM_TRADE_DIR    direction;
    ENUM_FILTER_FAIL  blockReason;
    
    bool              c1RangeValid;
    bool              c2Sweep;
    bool              c3VolExhaust;
    bool              c4Rejection;
    bool              c5RSIExtreme;
    
    double            sweepLevel;
    double            slPrice;
    double            tpPrice;
    double            entryPrice;
    double            confidence;
    double            vwap;
    double            spreadPips;
};

// Neural Feedback
struct NeuralStats {
    int               totalTrades;
    int               wins;
    double            accuracy;
    bool              isPaused;
    datetime          pausedUntil;
};

NeuralStats gNFE1;
NeuralStats gNFE2;
datetime          gLastClosedTrade = 0;

// Order Block Storage
struct OrderBlock {
    double            hi;
    double            lo;
    datetime          time;
    bool              isBull;
    double            strength;
};

OrderBlock     gBullOB[];
OrderBlock     gBearOB[];
int            gBullOBCount = 0;
int            gBearOBCount = 0;

// FVG Storage
struct FVG {
    double            hi;
    double            lo;
    datetime          time;
    bool              isBull;
    bool              isFilled;
    double            sizePips;
};

FVG           gBullFVG[];
FVG           gBearFVG[];
int            gBullFVGCount = 0;
int            gBearFVGCount = 0;

// Asia Range
struct AsiaRange {
    double            hi;
    double            lo;
    double            mid;
    double            sizePips;
    datetime          builtDate;
    bool              isValid;
    bool              hiSwept;
    bool              loSwept;
};

AsiaRange     gAsiaRange;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                             |
//+------------------------------------------------------------------+
int OnInit() {
    // Select symbol
    if(!SymbolSelect(InpSymbol, true)) {
        Print("ERROR: Symbol ", InpSymbol, " not found!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Initialize arrays
    ArrayResize(gBullOB, 50);
    ArrayResize(gBearOB, 50);
    ArrayResize(gBullFVG, 30);
    ArrayResize(gBearFVG, 30);
    
    // Reset stats
    ZeroMemory(gNFE1);
    ZeroMemory(gNFE2);
    
    Print("=================================================");
    Print("  INSTITUTIONAL ALPHA ENGINE v5.1 - MQL5 INITIALIZED");
    Print("  Symbol: ", InpSymbol, " | Magic: ", InpMagic);
    Print("=================================================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| EXPERT TICK FUNCTION                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Update engine state
    gEngineState = GetEngineState();
    
    // Check for closed trades and update neural feedback
    CheckClosedTrades();
    
    // Process based on engine state
    if(gEngineState == ENGINE_KILLZONE) {
        ProcessEngine1();
    }
    else if(gEngineState == ENGINE_OFFZONE) {
        ProcessEngine2();
    }
    // ENGINE_DEAD: No trading
    
    // Position management
    ManagePositions();
}

//+------------------------------------------------------------------+
//| PROCESS ENGINE 1: SMC KILL ZONE                                   |
//+------------------------------------------------------------------+
void ProcessEngine1() {
    SMCResult r;
    ZeroMemory(r);
    
    // Get current data
    r.spreadPips = GetSpreadPips();
    r.vixLevel = GetVIXLevel();
    r.vixClear = (r.vixLevel > 0 && r.vixLevel < InpVIXMax);
    
    // Get bias
    gBias = DetectBias(PERIOD_H1, 30);
    ENUM_MARKET_BIAS bias2 = DetectBias(PERIOD_H4, 20);
    
    bool bullBias = (gBias == BIAS_BULL || bias2 == BIAS_BULL);
    bool bearBias = (gBias == BIAS_BEAR || bias2 == BIAS_BEAR);
    
    ENUM_TRADE_DIR checkDir = DIR_NONE;
    if(bullBias && (!bearBias || gBias == BIAS_BULL)) checkDir = DIR_BUY;
    else if(bearBias && (!bullBias || gBias == BIAS_BEAR)) checkDir = DIR_SELL;
    else checkDir = (gBias == BIAS_RANGE) ? DIR_NONE : checkDir;
    
    if(bullBias || bearBias) {
        // Scan structures
        ScanOrderBlocks(gBias);
        ScanFVGs();
        BuildVolumeProfile(r);
        
        // Evaluate pillars
        double obStr = GetOBStrength(checkDir, r.obAgeBars, r.obIsFresh);
        r.hasOB = (obStr >= InpOBMinStrength && r.obIsFresh);
        r.obStrength = obStr;
        
        r.hasFVG = CheckFVG(checkDir);
        r.hasVolSpike = CheckVolumeSpike();
        r.hasDivergence = CheckDivergence(checkDir);
        r.adxValue = GetADX();
        r.hasADX = (r.adxValue >= InpADXMin);
        
        // ICT Concepts
        r.hasDisplacement = CheckDisplacement(checkDir);
        r.hasBreakerBlock = CheckBreakerBlock(checkDir, r.breakerStrength);
        r.hasAbsorption = CheckAbsorption(checkDir, r.absRatio);
        
        SessionMomentum sm = GetSessionMomentum(checkDir);
        r.hasSessionMomentum = (sm.direction == checkDir && sm.strength >= 70);
        r.momentumStrength = sm.strength;
        r.momentumDir = sm.direction;
        
        // SMC Score (5 pillars)
        r.smcScore = 0;
        if(r.hasOB) r.smcScore++;
        if(r.hasFVG) r.smcScore++;
        if(r.hasVolSpike) r.smcScore++;
        if(r.hasDivergence) r.smcScore++;
        if(r.hasADX) r.smcScore++;
        
        // Confidence
        r.confidence = CalculateConfidence(r);
    }
    
    // Alpha filters
    r.dxyConfirmed = CheckDXY(checkDir);
    r.deltaPositive = CheckDelta(checkDir);
    r.vpZoneValid = CheckVPZone(checkDir, r.vpPOC, r.vpVAH, r.vpVAL);
    r.inKillZone = true;
    r.killZoneType = GetKillZoneType();
    
    // === GATE CHECKS ===
    
    // Gate 1: Spread
    if(r.spreadPips > InpMaxSpread) {
        r.blockReason = FAIL_SPREAD;
        PrintR("E1 BLOCKED: Spread too wide - ", r.spreadPips, " pips");
        return;
    }
    
    // Gate 2: VIX
    if(!r.vixClear) {
        r.blockReason = FAIL_VIX;
        PrintR("E1 BLOCKED: VIX halted - ", r.vixLevel);
        return;
    }
    
    // Gate 3: Bias
    if(gBias == BIAS_RANGE) {
        r.blockReason = FAIL_SMC;
        PrintR("E1 BLOCKED: No bias (ranging)");
        return;
    }
    
    // Gate 4: SMC Score
    if(r.smcScore < InpMinConfirm) {
        r.blockReason = FAIL_SMC;
        PrintR("E1 BLOCKED: SMC Score ", r.smcScore, "/5");
        return;
    }
    
    // Gate 5: MSS
    if(!CheckMSS(checkDir)) {
        r.blockReason = FAIL_SMC;
        PrintR("E1 BLOCKED: MSS not confirmed");
        return;
    }
    
    // Gate 6: Session Momentum
    if(!r.hasSessionMomentum && r.momentumDir != DIR_NONE && r.momentumDir != checkDir) {
        r.blockReason = FAIL_SMC;
        PrintR("E1 BLOCKED: Session momentum opposes trade");
        return;
    }
    
    // Gate 7: DXY
    if(InpUseDXY && !r.dxyConfirmed) {
        r.blockReason = FAIL_DXY;
        PrintR("E1 BLOCKED: DXY correlation failed");
        return;
    }
    
    // Gate 8: VP
    if(InpUseVP && !r.vpZoneValid) {
        r.blockReason = FAIL_VP;
        PrintR("E1 BLOCKED: Price at POC zone");
        return;
    }
    
    // Gate 9: Displacement (FAIL CLOSED)
    if(InpUseDisplacement && !r.hasDisplacement) {
        r.blockReason = FAIL_DISP;
        PrintR("E1 BLOCKED: No displacement detected");
        return;
    }
    
    // Gate 10: Breaker Block (FAIL CLOSED)
    if(InpUseBreakerBlock && !r.hasBreakerBlock) {
        r.blockReason = FAIL_BREAKER;
        PrintR("E1 BLOCKED: No breaker block");
        return;
    }
    
    // Gate 11: Delta
    if(!r.deltaPositive) {
        r.blockReason = FAIL_DELTA;
        PrintR("E1 BLOCKED: Delta not aligned");
        return;
    }
    
    // === ALL GATES PASSED - OPEN TRADE ===
    
    // Check existing position
    if(PositionSelect(InpSymbol)) {
        if(PositionGetInteger(POSITION_MAGIC) == InpMagic) {
            return; // Already have position
        }
    }
    
    // Calculate levels
    double atr = GetATR();
    double tick = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
    if(checkDir == DIR_SELL) tick = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    
    double sl, tp1, tp2;
    if(checkDir == DIR_BUY) {
        sl  = tick - atr * InpATRSLMult;
        tp1 = tick + (tick - sl) * InpTP1RR;
        tp2 = tick + (tick - sl) * InpTP2RR;
    } else {
        sl  = tick + atr * InpATRSLMult;
        tp1 = tick - (sl - tick) * InpTP1RR;
        tp2 = tick - (sl - tick) * InpTP2RR;
    }
    
    // Check RR
    double rr = MathAbs(tp2 - tick) / MathAbs(sl - tick);
    if(rr < InpTP1RR) {
        PrintR("E1 BLOCKED: Low R:R - ", rr);
        return;
    }
    
    // Calculate lot
    double lot = CalculateLot(InpSymbol, MathAbs(sl - tick));
    
    // Open trade
    if(OpenTrade(InpSymbol, checkDir, lot, sl, tp1, tp2, "IAE_v5_E1")) {
        gTicket++;
        PrintR("E1 TRADE OPENED: ", checkDir == DIR_BUY ? "BUY" : "SELL", 
                " | Lot:", lot, " | SL:", sl, " | TP1:", tp1, " | TP2:", tp2);
    }
}

//+------------------------------------------------------------------+
//| PROCESS ENGINE 2: MEAN REVERSION                                  |
//+------------------------------------------------------------------+
void ProcessEngine2() {
    RevResult r;
    ZeroMemory(r);
    
    r.spreadPips = GetSpreadPips();
    
    // Build Asia range
    BuildAsiaRange(r);
    
    // Detect sweep
    DetectSweep(r);
    
    // Additional checks
    if(r.c2Sweep) {
        r.c3VolExhaust = CheckVolExhaustion(r.sweepLevel);
        r.c4Rejection = CheckRejection(r.direction);
        r.c5RSIExtreme = CheckRSIExtreme(r.direction);
    }
    
    // Confidence
    r.confidence = 0;
    if(r.c1RangeValid) r.confidence += 15;
    if(r.c2Sweep) r.confidence += 25;
    if(r.c3VolExhaust) r.confidence += 20;
    if(r.c4Rejection) r.confidence += 20;
    if(r.c5RSIExtreme) r.confidence += 20;
    
    // === GATE CHECKS ===
    
    // Gate 1: Spread
    if(r.spreadPips > InpMaxSpreadE2) {
        r.blockReason = FAIL_SPREAD;
        PrintR("E2 BLOCKED: Spread - ", r.spreadPips);
        return;
    }
    
    // Gate 2: Range
    if(!r.c1RangeValid) {
        r.blockReason = FAIL_SMC;
        PrintR("E2 BLOCKED: No valid Asia range");
        return;
    }
    
    // Gate 3: Sweep
    if(!r.c2Sweep) {
        r.blockReason = FAIL_SMC;
        PrintR("E2 BLOCKED: No sweep");
        return;
    }
    
    // Gate 4: Vol Exhaustion
    if(!r.c3VolExhaust) {
        r.blockReason = FAIL_SMC;
        PrintR("E2 BLOCKED: No vol exhaustion");
        return;
    }
    
    // Gate 5: Rejection
    if(!r.c4Rejection) {
        r.blockReason = FAIL_SMC;
        PrintR("E2 BLOCKED: No rejection candle");
        return;
    }
    
    // Gate 6: RSI
    if(!r.c5RSIExtreme) {
        r.blockReason = FAIL_SMC;
        PrintR("E2 BLOCKED: RSI not extreme");
        return;
    }
    
    // === ALL GATES PASSED ===
    
    // Check existing position
    if(PositionSelect(InpSymbol)) {
        if(PositionGetInteger(POSITION_MAGIC) == InpMagic) {
            return;
        }
    }
    
    // Calculate levels
    double tick = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
    if(r.direction == DIR_SELL) tick = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    
    double pip = GetPipSize(InpSymbol);
    double slBuf = InpE2SweepPips * pip * 3;
    double sl, tp;
    
    if(r.direction == DIR_BUY) {
        sl = gAsiaRange.lo - slBuf;
        tp = CalculateE2TP(r.direction, tick);
    } else {
        sl = gAsiaRange.hi + slBuf;
        tp = CalculateE2TP(r.direction, tick);
    }
    
    // Check RR
    double risk = MathAbs(tick - sl);
    double reward = MathAbs(tp - tick);
    if(reward < risk * 0.9) {
        PrintR("E2 BLOCKED: Low R:R");
        return;
    }
    
    // Open trade
    if(OpenTrade(InpSymbol, r.direction, InpFixedLot, sl, tp, 0, "IAE_v5_E2")) {
        gTicket++;
        PrintR("E2 TRADE OPENED: ", r.direction == DIR_BUY ? "BUY" : "SELL");
    }
}

//+------------------------------------------------------------------+
//| POSITION MANAGEMENT                                              |
//+------------------------------------------------------------------+
void ManagePositions() {
    if(!PositionSelect(InpSymbol)) return;
    if(PositionGetInteger(POSITION_MAGIC) != InpMagic) return;
    
    double entry    = PositionGetDouble(POSITION_PRICE_OPEN);
    double cur      = PositionGetDouble(POSITION_PRICE_CURRENT);
    double sl       = PositionGetDouble(POSITION_SL);
    double tp       = PositionGetDouble(POSITION_TP);
    double vol      = PositionGetDouble(POSITION_VOLUME);
    bool   isBuy    = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    long   ticket   = PositionGetInteger(POSITION_TICKET);
    
    double pip = GetPipSize(InpSymbol);
    double pt = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    double profitPts = MathAbs(cur - entry) / pt;
    double riskPts = MathAbs(entry - sl) / pt;
    
    // Engine 1: Partial close at TP1, then BE
    string comment = PositionGetString(POSITION_COMMENT);
    if(StringFind(comment, "IAE_v5_E1") >= 0) {
        // Check TP1 hit - partial close
        double tp1Hit = isBuy ? (cur >= tp) : (cur <= tp);
        if(tp1Hit && StringFind(comment, "PARTIAL") < 0) {
            // Close 50% position
            double closeVol = vol * 0.5;
            if(ClosePartial(ticket, closeVol)) {
                // Move SL to BE
                double beBuf = InpBEBufferE1 * pip;
                double newSL = isBuy ? (entry + beBuf) : (entry - beBuf);
                ModifySL(ticket, newSL);
                PrintR("E1 PARTIAL CLOSE + BE");
            }
        }
        
        // ATR Trailing (after partial)
        if(StringFind(comment, "PARTIAL") >= 0) {
            double atr = GetATR(PERIOD_H1);
            double trailSL = isBuy ? (cur - atr * InpTrailATR) : (cur + atr * InpTrailATR);
            
            bool shouldTrail = isBuy ? (trailSL > sl && trailSL < cur) 
                                     : (trailSL < sl && trailSL > cur);
            
            if(shouldTrail) {
                ModifySL(ticket, trailSL);
            }
        }
    }
    
    // Engine 2: BE at +10 pips
    if(StringFind(comment, "IAE_v5_E2") >= 0) {
        double profitPips = MathAbs(cur - entry) / pip;
        
        if(profitPips >= InpBETiggerE2 && sl == 0) {
            double beBuf = InpBEBuffer * pip;
            double newSL = isBuy ? (entry + beBuf) : (entry - beBuf);
            
            bool ok = isBuy ? (newSL > sl) : (newSL < sl);
            if(ok) {
                ModifySL(ticket, newSL);
                PrintR("E2 BE SET");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| CHECK CLOSED TRADES                                              |
//+------------------------------------------------------------------+
void CheckClosedTrades() {
    HistorySelect(gLastClosedTrade, TimeCurrent());
    
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
        if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
        
        string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        bool isWin = (profit > 0);
        
        ENUM_ENGINE_STATE engine = ENGINE_KILLZONE;
        if(StringFind(comment, "IAE_v5_E2") >= 0) engine = ENGINE_OFFZONE;
        else continue; // Unknown engine
        
        // Update neural feedback
        NeuralStats &nf = (engine == ENGINE_KILLZONE) ? gNFE1 : gNFE2;
        nf.totalTrades++;
        if(isWin) nf.wins++;
        nf.accuracy = (nf.wins * 100.0) / nf.totalTrades;
        
        // Circuit breaker
        if(nf.totalTrades >= InpNFMemory) {
            if(nf.accuracy < InpNFMinAcc && !nf.isPaused) {
                nf.isPaused = true;
                nf.pausedUntil = TimeCurrent() + InpNFPauseMins * 60;
                PrintR("CIRCUIT BREAKER: Engine paused | Acc:", nf.accuracy);
            }
            else if(nf.accuracy >= 85.0) {
                nf.isPaused = false;
            }
        }
        
        PrintR("TRADE CLOSED: ", isWin ? "WIN" : "LOSS", " | P&L:", profit, 
               " | Acc:", nf.accuracy, "%");
    }
    
    gLastClosedTrade = TimeCurrent();
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                 |
//+------------------------------------------------------------------+

ENUM_ENGINE_STATE GetEngineState() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int utcHour = dt.hour - InpGMT;
    if(utcHour < 0) utcHour += 24;
    
    // Dead zone check
    if(utcHour >= InpDeadZoneStart || utcHour < InpAsiaOpen) {
        return ENGINE_DEAD;
    }
    
    // DST-aware London/NY time
    bool isDST = (dt.mon > 3 && dt.mon < 10) || 
                 (dt.mon == 3 && dt.day >= 25) || 
                 (dt.mon == 10 && dt.day < 25);
    
    int ukHour = (utcHour + (isDST ? 1 : 0)) % 24;
    int estHour = (utcHour + (isDST ? 4 : 5)) % 24;
    
    // London KZ
    if(ukHour >= InpLondonStartUK && ukHour < InpLondonEndUK) {
        return ENGINE_KILLZONE;
    }
    
    // NY KZ
    if(estHour >= InpNYStartEST && estHour < InpNYEndEST) {
        return ENGINE_KILLZONE;
    }
    
    return ENGINE_OFFZONE;
}

string GetKillZoneType() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int utcHour = dt.hour - InpGMT;
    if(utcHour < 0) utcHour += 24;
    
    bool isDST = (dt.mon > 3 && dt.mon < 10);
    int ukHour = (utcHour + (isDST ? 1 : 0)) % 24;
    int estHour = (utcHour + (isDST ? 4 : 5)) % 24;
    
    if(ukHour >= InpLondonStartUK && ukHour < InpLondonEndUK) return "LONDON";
    if(estHour >= InpNYStartEST && estHour < InpNYEndEST) return "NY";
    return "";
}

ENUM_MARKET_BIAS DetectBias(ENUM_TIMEFRAMES tf, int bars) {
    double high[], low[];
    ArrayResize(high, bars);
    ArrayResize(low, bars);
    
    if(CopyHigh(InpSymbol, tf, 0, bars, high) <= 0) return BIAS_RANGE;
    if(CopyLow(InpSymbol, tf, 0, bars, low) <= 0) return BIAS_RANGE;
    
    int hh = 0, hl = 0, lh = 0, ll = 0;
    double prevH = -1, prevL = -1;
    bool lastWasHigh = false;
    
    for(int i = 2; i < bars - 2; i++) {
        bool isSWH = (high[i] > high[i-1] && high[i] > high[i+1] && 
                     high[i] > high[i-2] && high[i] > high[i+2]);
        bool isSWL = (low[i] < low[i-1] && low[i] < low[i+1] && 
                     low[i] < low[i-2] && low[i] < low[i+2]);
        
        if(isSWH && !lastWasHigh) {
            hh += (high[i] > prevH && prevH > 0) ? 1 : 0;
            lh += (high[i] <= prevH && prevH > 0) ? 1 : 0;
            prevH = high[i];
            lastWasHigh = true;
        }
        if(isSWL && lastWasHigh) {
            hl += (low[i] > prevL && prevL > 0) ? 1 : 0;
            ll += (low[i] <= prevL && prevL > 0) ? 1 : 0;
            prevL = low[i];
            lastWasHigh = false;
        }
    }
    
    if(hh >= 2 && hl >= 1) return BIAS_BULL;
    if(ll >= 2 && lh >= 1) return BIAS_BEAR;
    return BIAS_RANGE;
}

double GetSpreadPips() {
    double spread = SymbolInfoInteger(InpSymbol, SYMBOL_SPREAD);
    return spread * GetPipSize(InpSymbol);
}

double GetPipSize(string symbol) {
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    if(digits == 3 || digits == 5) return SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
    return SymbolInfoDouble(symbol, SYMBOL_POINT);
}

double GetADX() {
    double adx[];
    int handle = iADX(InpSymbol, PERIOD_M15, InpADXPeriod);
    if(handle == INVALID_HANDLE) return 0;
    if(CopyBuffer(handle, 0, 0, 1, adx) <= 0) {
        IndicatorRelease(handle);
        return 0;
    }
    IndicatorRelease(handle);
    return adx[0];
}

double GetATR(ENUM_TIMEFRAMES tf = PERIOD_M15) {
    double atr[];
    int handle = iATR(InpSymbol, tf, 14);
    if(handle == INVALID_HANDLE) return 0;
    if(CopyBuffer(handle, 0, 0, 1, atr) <= 0) {
        IndicatorRelease(handle);
        return 0;
    }
    IndicatorRelease(handle);
    return atr[0];
}

double GetVIXLevel() {
    double tick = SymbolInfoDouble(InpVIXSymbol, SYMBOL_BID);
    if(tick <= 0 || tick > 200) return 0; // Invalid or synthetic
    return tick;
}

//+------------------------------------------------------------------+
//| ORDER BLOCK DETECTION                                            |
//+------------------------------------------------------------------+
void ScanOrderBlocks(ENUM_MARKET_BIAS bias) {
    gBullOBCount = 0;
    gBearOBCount = 0;
    
    double cur = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    double atr = GetATR();
    if(atr <= 0) return;
    
    // Scan H1 and M5
    ENUM_TIMEFRAMES tfs[] = {PERIOD_H1, PERIOD_M5};
    
    for(int t = 0; t < 2; t++) {
        ENUM_TIMEFRAMES tf = tfs[t];
        
        double open[], high[], low[], close[], vol[];
        int count = InpOBLookback + 5;
        
        if(CopyOpen(InpSymbol, tf, 0, count, open) <= 0) continue;
        if(CopyHigh(InpSymbol, tf, 0, count, high) <= 0) continue;
        if(CopyLow(InpSymbol, tf, 0, count, low) <= 0) continue;
        if(CopyClose(InpSymbol, tf, 0, count, close) <= 0) continue;
        if(CopyTickVolume(InpSymbol, tf, 0, count, vol) <= 0) continue;
        
        for(int i = 2; i < count - 2; i++) {
            int age = i;
            
            // Age filter
            if(age < InpOBMinAgeBars || age > InpOBMaxAgeBars) continue;
            
            double impulse = high[i-1] - low[i-1];
            if(impulse < atr) continue;
            
            double pip = GetPipSize(InpSymbol);
            
            // Bullish OB
            if(close[i] < open[i] && close[i-1] > open[i-1] && cur >= low[i]) {
                double volAvg = 0;
                for(int j = i; j < MathMin(i+10, count); j++) volAvg += vol[j];
                volAvg /= MathMin(10, count - i);
                double vr = MathMin(vol[i-1] / (volAvg + 0.0001), 4.0);
                
                double strength = 40 * MathMin(impulse / atr, 2.5) / 2.5 +
                                 35 * MathMin(vr, 2.0) / 2.0 +
                                 25 * (bias == BIAS_BULL ? 1.0 : 0.3);
                
                strength = MathMin(strength, 100);
                
                if(gBullOBCount < 50) {
                    gBullOB[gBullOBCount].hi = high[i];
                    gBullOB[gBullOBCount].lo = low[i];
                    gBullOB[gBullOBCount].isBull = true;
                    gBullOB[gBullOBCount].strength = strength;
                    gBullOB[gBullOBCount].time = iTime(InpSymbol, tf, count-i-1);
                    gBullOBCount++;
                }
            }
            
            // Bearish OB
            if(close[i] > open[i] && close[i-1] < open[i-1] && cur <= high[i]) {
                double volAvg = 0;
                for(int j = i; j < MathMin(i+10, count); j++) volAvg += vol[j];
                volAvg /= MathMin(10, count - i);
                double vr = MathMin(vol[i-1] / (volAvg + 0.0001), 4.0);
                
                double strength = 40 * MathMin(impulse / atr, 2.5) / 2.5 +
                                 35 * MathMin(vr, 2.0) / 2.0 +
                                 25 * (bias == BIAS_BEAR ? 1.0 : 0.3);
                
                strength = MathMin(strength, 100);
                
                if(gBearOBCount < 50) {
                    gBearOB[gBearOBCount].hi = high[i];
                    gBearOB[gBearOBCount].lo = low[i];
                    gBearOB[gBearOBCount].isBull = false;
                    gBearOB[gBearOBCount].strength = strength;
                    gBearOB[gBearOBCount].time = iTime(InpSymbol, tf, count-i-1);
                    gBearOBCount++;
                }
            }
        }
    }
}

double GetOBStrength(ENUM_TRADE_DIR dir, int &ageBars, bool &isFresh) {
    double cur = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    double pip = GetPipSize(InpSymbol);
    double buf = InpOBBuffPips * pip;
    
    OrderBlock arr[];
    int count;
    
    if(dir == DIR_BUY) {
        arr = gBullOB;
        count = gBullOBCount;
    } else {
        arr = gBearOB;
        count = gBearOBCount;
    }
    
    for(int i = 0; i < count; i++) {
        if(arr[i].lo - buf <= cur && cur <= arr[i].hi + buf) {
            ageBars = (int)((TimeCurrent() - arr[i].time) / 60 / 5); // Approx M5 bars
            isFresh = true;
            return arr[i].strength;
        }
    }
    
    ageBars = 0;
    isFresh = false;
    return 0;
}

//+------------------------------------------------------------------+
//| FVG DETECTION                                                    |
//+------------------------------------------------------------------+
void ScanFVGs() {
    gBullFVGCount = 0;
    gBearFVGCount = 0;
    
    double high[], low[], close[];
    int count = 60;
    
    if(CopyHigh(InpSymbol, PERIOD_M15, 0, count, high) <= 0) return;
    if(CopyLow(InpSymbol, PERIOD_M15, 0, count, low) <= 0) return;
    if(CopyClose(InpSymbol, PERIOD_M15, 0, count, close) <= 0) return;
    
    double cur = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    double pip = GetPipSize(InpSymbol);
    double minPips = InpFVGMinPips * pip;
    
    for(int i = 2; i < MathMin(count, InpFVGMaxAge + 5) - 2; i++) {
        // Bullish FVG
        if(low[i-2] > high[i] && (low[i-2] - high[i]) >= minPips) {
            bool inGap = (cur <= low[i-2] && cur >= high[i]);
            bool notFilled = (cur > high[i]);
            
            if(inGap && notFilled && gBullFVGCount < 30) {
                gBullFVG[gBullFVGCount].hi = low[i-2];
                gBullFVG[gBullFVGCount].lo = high[i];
                gBullFVG[gBullFVGCount].isBull = true;
                gBullFVG[gBullFVGCount].sizePips = (low[i-2] - high[i]) / pip;
                gBullFVG[gBullFVGCount].time = iTime(InpSymbol, PERIOD_M15, count-i-1);
                gBullFVGCount++;
            }
        }
        
        // Bearish FVG
        if(high[i-2] < low[i] && (low[i] - high[i-2]) >= minPips) {
            bool inGap = (cur >= high[i-2] && cur <= low[i]);
            bool notFilled = (cur < low[i]);
            
            if(inGap && notFilled && gBearFVGCount < 30) {
                gBearFVG[gBearFVGCount].hi = low[i];
                gBearFVG[gBearFVGCount].lo = high[i-2];
                gBearFVG[gBearFVGCount].isBull = false;
                gBearFVG[gBearFVGCount].sizePips = (low[i] - high[i-2]) / pip;
                gBearFVG[gBearFVGCount].time = iTime(InpSymbol, PERIOD_M15, count-i-1);
                gBearFVGCount++;
            }
        }
    }
}

bool CheckFVG(ENUM_TRADE_DIR dir) {
    double cur = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    
    if(dir == DIR_BUY) {
        for(int i = 0; i < gBullFVGCount; i++) {
            if(gBullFVG[i].lo <= cur && cur <= gBullFVG[i].hi) {
                return true;
            }
        }
    } else {
        for(int i = 0; i < gBearFVGCount; i++) {
            if(gBearFVG[i].lo <= cur && cur <= gBearFVG[i].hi) {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| ICT CONCEPT DETECTIONS                                           |
//+------------------------------------------------------------------+

bool CheckDisplacement(ENUM_TRADE_DIR dir) {
    if(!InpUseDisplacement) return true;
    
    double high[], low[], open[], close[], vol[];
    if(CopyHigh(InpSymbol, PERIOD_M5, 0, 25, high) <= 0) return true; // Fail open
    if(CopyLow(InpSymbol, PERIOD_M5, 0, 25, low) <= 0) return true;
    if(CopyOpen(InpSymbol, PERIOD_M5, 0, 25, open) <= 0) return true;
    if(CopyClose(InpSymbol, PERIOD_M5, 0, 25, close) <= 0) return true;
    if(CopyTickVolume(InpSymbol, PERIOD_M5, 0, 25, vol) <= 0) return true;
    
    double volAvg = 0;
    for(int i = 5; i < 20; i++) volAvg += vol[i];
    volAvg /= 15;
    
    for(int i = 1; i < 6; i++) {
        double volRatio = vol[i] / (volAvg + 0.001);
        if(volRatio < InpDispVolMult) continue;
        
        if(dir == DIR_BUY) {
            // Bullish engulfing
            double prevHi = high[i+1];
            double prevLo = low[i+1];
            for(int j = 2; j <= InpDispMinBars; j++) {
                if(i+j < 25) {
                    prevHi = MathMax(prevHi, high[i+j]);
                    prevLo = MathMin(prevLo, low[i+j]);
                }
            }
            
            if(close[i] > prevHi && open[i] < prevLo && 
               close[i] > open[i+1] && volRatio >= InpDispVolMult) {
                return true;
            }
        } else {
            // Bearish engulfing
            double prevHi = high[i+1];
            double prevLo = low[i+1];
            for(int j = 2; j <= InpDispMinBars; j++) {
                if(i+j < 25) {
                    prevHi = MathMax(prevHi, high[i+j]);
                    prevLo = MathMin(prevLo, low[i+j]);
                }
            }
            
            if(close[i] < prevLo && open[i] > prevHi && 
               close[i] < open[i+1] && volRatio >= InpDispVolMult) {
                return true;
            }
        }
    }
    
    return false; // Fail closed
}

bool CheckBreakerBlock(ENUM_TRADE_DIR dir, double &strength) {
    strength = 0;
    if(!InpUseBreakerBlock) return true;
    
    double high[], low[], close[];
    if(CopyHigh(InpSymbol, PERIOD_M5, 0, 35, high) <= 0) return true;
    if(CopyLow(InpSymbol, PERIOD_M5, 0, 35, low) <= 0) return true;
    if(CopyClose(InpSymbol, PERIOD_M5, 0, 35, close) <= 0) return true;
    
    double cur = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    double pip = GetPipSize(InpSymbol);
    
    // Find swing points
    double swingHighs[], swingLows[];
    int shCount = 0, slCount = 0;
    ArrayResize(swingHighs, 10);
    ArrayResize(swingLows, 10);
    
    for(int i = 3; i < 30; i++) {
        bool isSWH = (high[i] > high[i-1] && high[i] > high[i+1] && 
                     high[i] > high[i-2] && high[i] > high[i+2]);
        bool isSWL = (low[i] < low[i-1] && low[i] < low[i+1] && 
                     low[i] < low[i-2] && low[i] < low[i+2]);
        
        if(isSWH && shCount < 10) {
            swingHighs[shCount++] = high[i];
        }
        if(isSWL && slCount < 10) {
            swingLows[slCount++] = low[i];
        }
    }
    
    if(dir == DIR_BUY) {
        // Check recent swing lows
        for(int i = 0; i < MathMin(5, slCount); i++) {
            double slPrice = swingLows[i];
            bool broken = false, returned = false;
            
            for(int j = 1; j < i; j++) {
                if(low[j] < slPrice) broken = true;
                if(MathAbs(close[j] - slPrice) < 5 * pip) returned = true;
            }
            
            if(broken && returned) {
                double dist = (slPrice - cur) / pip;
                if(dist > 0 && dist < 30) {
                    strength = MathMin(100, 50 + 30 * (1 - dist/30));
                    return true;
                }
            }
        }
    } else {
        for(int i = 0; i < MathMin(5, shCount); i++) {
            double shPrice = swingHighs[i];
            bool broken = false, returned = false;
            
            for(int j = 1; j < i; j++) {
                if(high[j] > shPrice) broken = true;
                if(MathAbs(close[j] - shPrice) < 5 * pip) returned = true;
            }
            
            if(broken && returned) {
                double dist = (cur - shPrice) / pip;
                if(dist > 0 && dist < 30) {
                    strength = MathMin(100, 50 + 30 * (1 - dist/30));
                    return true;
                }
            }
        }
    }
    
    return false;
}

bool CheckAbsorption(ENUM_TRADE_DIR dir, double &ratio) {
    ratio = 0;
    if(!InpUseAbsorption) return true;
    
    double high[], low[], close[], vol[];
    if(CopyHigh(InpSymbol, PERIOD_M5, 0, 25, high) <= 0) return true;
    if(CopyLow(InpSymbol, PERIOD_M5, 0, 25, low) <= 0) return true;
    if(CopyClose(InpSymbol, PERIOD_M5, 0, 25, close) <= 0) return true;
    if(CopyTickVolume(InpSymbol, PERIOD_M5, 0, 25, vol) <= 0) return true;
    
    double volAvg = 0;
    for(int i = 5; i < 20; i++) volAvg += vol[i];
    volAvg /= 15;
    
    double pip = GetPipSize(InpSymbol);
    
    for(int i = 1; i < 10; i++) {
        double volRatio = vol[i] / (volAvg + 0.001);
        double priceRange = (high[i] - low[i]) / pip;
        
        if(volRatio >= InpAbsVolMult && priceRange < 5) {
            ratio = volRatio;
            return true;
        }
    }
    
    return false;
}

struct SessionMomentum {
    ENUM_TRADE_DIR direction;
    double strength;
};

SessionMomentum GetSessionMomentum(ENUM_TRADE_DIR tradeDir) {
    SessionMomentum sm;
    sm.direction = DIR_NONE;
    sm.strength = 0;
    
    double open[], close[];
    if(CopyOpen(InpSymbol, PERIOD_M5, 0, InpSessionMomBars + 5, open) <= 0) return sm;
    if(CopyClose(InpSymbol, PERIOD_M5, 0, InpSessionMomBars + 5, close) <= 0) return sm;
    
    int bullBars = 0, bearBars = 0;
    int startIdx = ArraySize(open) - InpSessionMomBars;
    
    for(int i = startIdx; i < ArraySize(open); i++) {
        if(close[i] > open[i]) bullBars++;
        else if(close[i] < open[i]) bearBars++;
    }
    
    int total = bullBars + bearBars;
    if(total == 0) return sm;
    
    if(bullBars > bearBars) {
        sm.direction = DIR_BUY;
        sm.strength = (double)(bullBars - bearBars) * 100.0 / total;
    } else if(bearBars > bullBars) {
        sm.direction = DIR_SELL;
        sm.strength = (double)(bearBars - bullBars) * 100.0 / total;
    }
    
    return sm;
}

//+------------------------------------------------------------------+
//| ADDITIONAL CHECKS                                                |
//+------------------------------------------------------------------+

bool CheckVolumeSpike() {
    double vol[];
    if(CopyTickVolume(InpSymbol, PERIOD_M5, 0, InpVolSpikeMult * 5 + 5, vol) <= 0) return false;
    
    double avg = 0;
    for(int i = 1; i <= 20; i++) avg += vol[i];
    avg /= 20;
    
    return (vol[0] / (avg + 0.001) >= InpVolSpikeMult);
}

bool CheckDivergence(ENUM_TRADE_DIR dir) {
    double close[], high[], low[];
    if(CopyClose(InpSymbol, PERIOD_M5, 0, 30, close) <= 0) return false;
    if(CopyHigh(InpSymbol, PERIOD_M5, 0, 30, high) <= 0) return false;
    if(CopyLow(InpSymbol, PERIOD_M5, 0, 30, low) <= 0) return false;
    
    double rsi[], macd[], signal[];
    int rsiHandle = iRSI(InpSymbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
    int macdHandle = iMACD(InpSymbol, PERIOD_M5, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
    
    if(rsiHandle != INVALID_HANDLE) {
        if(CopyBuffer(rsiHandle, 0, 0, 30, rsi) <= 0) {
            IndicatorRelease(rsiHandle);
            return false;
        }
        IndicatorRelease(rsiHandle);
    } else return false;
    
    if(macdHandle != INVALID_HANDLE) {
        if(CopyBuffer(macdHandle, 1, 0, 30, macd) <= 0) {
            IndicatorRelease(macdHandle);
            return false;
        }
        IndicatorRelease(macdHandle);
    } else return false;
    
    if(dir == DIR_BUY) {
        // Find two lowest lows
        int l1 = 1, l2 = -1;
        for(int i = 2; i < 8; i++) {
            if(low[i] < low[l1] && i < ArraySize(low)) {
                l2 = l1;
                l1 = i;
            }
        }
        if(l2 < 0 || l2 >= ArraySize(rsi) || l1 >= ArraySize(rsi)) return false;
        
        return (low[l1] < low[l2] && rsi[l1] > rsi[l2] && 
                macd[1] > macd[3]);
    } else {
        int h1 = 1, h2 = -1;
        for(int i = 2; i < 8; i++) {
            if(high[i] > high[h1] && i < ArraySize(high)) {
                h2 = h1;
                h1 = i;
            }
        }
        if(h2 < 0 || h2 >= ArraySize(rsi) || h1 >= ArraySize(rsi)) return false;
        
        return (high[h1] > high[h2] && rsi[h1] < rsi[h2] && 
                macd[1] < macd[3]);
    }
}

bool CheckDXY(ENUM_TRADE_DIR dir) {
    if(!InpUseDXY) return true;
    
    double close[];
    if(CopyClose(InpDXYSymbol, PERIOD_H1, 0, InpDXYLookback + 2, close) <= 0) return true;
    
    // Simple slope check
    double slope = (close[0] - close[InpDXYLookback-1]) / InpDXYLookback;
    
    bool needsEUR = (StringFind(InpSymbol, "EUR") >= 0 || 
                     StringFind(InpSymbol, "GBP") >= 0 ||
                     StringFind(InpSymbol, "AUD") >= 0 ||
                     StringFind(InpSymbol, "NZD") >= 0);
    
    if(needsEUR) {
        return (dir == DIR_BUY) ? (slope < 0) : (slope > 0);
    } else {
        return (dir == DIR_BUY) ? (slope > 0) : (slope < 0);
    }
}

bool CheckDelta(ENUM_TRADE_DIR dir) {
    // Simplified delta check using tick volume imbalance
    MqlTick ticks[];
    int copied = CopyTicks(InpSymbol, ticks, COPY_TICKS_TRADE, 0, 1000);
    if(copied <= 0) return true; // Fail open
    
    double buyVol = 0, sellVol = 0;
    for(int i = 0; i < copied; i++) {
        if((ticks[i].flags & TICK_FLAG_BUY) != 0) buyVol += ticks[i].volume;
        if((ticks[i].flags & TICK_FLAG_SELL) != 0) sellVol += ticks[i].volume;
    }
    
    double total = buyVol + sellVol;
    if(total <= 0) return true;
    
    double ratio = buyVol / total;
    double minRatio = 0.55;
    
    if(dir == DIR_BUY) return (ratio >= minRatio && buyVol > sellVol);
    else return (ratio <= (1 - minRatio) && sellVol > buyVol);
}

void BuildVolumeProfile(SMCResult &r) {
    if(!InpUseVP) {
        r.vpZoneValid = true;
        return;
    }
    
    double high[], low[], close[], vol[];
    if(CopyHigh(InpSymbol, PERIOD_M5, 0, InpVPBars, high) <= 0) return;
    if(CopyLow(InpSymbol, PERIOD_M5, 0, InpVPBars, low) <= 0) return;
    if(CopyClose(InpSymbol, PERIOD_M5, 0, InpVPBars, close) <= 0) return;
    if(CopyTickVolume(InpSymbol, PERIOD_M5, 0, InpVPBars, vol) <= 0) return;
    
    double hiMax = high[ArrayMaximum(high)];
    double loMin = low[ArrayMinimum(low)];
    
    if(hiMax <= loMin) return;
    
    int buckets = InpVPBuckets;
    double bSize = (hiMax - loMin) / buckets;
    double vols[];
    ArrayResize(vols, buckets);
    
    int size = ArraySize(high);
    for(int i = 0; i < size; i++) {
        double barRange = high[i] - low[i];
        if(barRange <= 0) continue;
        
        int loIdx = (int)((low[i] - loMin) / bSize);
        int hiIdx = (int)((high[i] - loMin) / bSize);
        loIdx = MathMax(0, MathMin(buckets-1, loIdx));
        hiIdx = MathMax(0, MathMin(buckets-1, hiIdx));
        
        for(int b = loIdx; b <= hiIdx; b++) {
            double blo = loMin + b * bSize;
            double bhi = blo + bSize;
            double ovlp = (MathMin(high[i], bhi) - MathMax(low[i], blo)) / barRange;
            if(ovlp > 0) vols[b] += vol[i] * ovlp;
        }
    }
    
    int pocIdx = ArrayMaximum(vols);
    r.vpPOC = loMin + (pocIdx + 0.5) * bSize;
    
    double total = 0;
    for(int i = 0; i < buckets; i++) total += vols[i];
    
    double target = total * InpVPValueArea / 100.0;
    double acc = vols[pocIdx];
    int vhi = pocIdx, vlo = pocIdx;
    
    while(acc < target && (vhi < buckets-1 || vlo > 0)) {
        double nHi = (vhi < buckets-1) ? vols[vhi+1] : 0;
        double nLo = (vlo > 0) ? vols[vlo-1] : 0;
        
        if(nHi >= nLo && vhi < buckets-1) { vhi++; acc += vols[vhi]; }
        else if(vlo > 0) { vlo--; acc += vols[vlo]; }
        else if(vhi < buckets-1) { vhi++; acc += vols[vhi]; }
        else break;
    }
    
    r.vpVAH = loMin + (vhi + 1.0) * bSize;
    r.vpVAL = loMin + vlo * bSize;
}

bool CheckVPZone(ENUM_TRADE_DIR dir, double poc, double vah, double val) {
    if(!InpUseVP || poc == 0) return true;
    
    double cur = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    double pip = GetPipSize(InpSymbol);
    
    if(MathAbs(cur - poc) <= 5 * pip) return false;
    if(dir == DIR_BUY && cur > vah) return false;
    if(dir == DIR_SELL && cur < val) return false;
    
    return true;
}

bool CheckMSS(ENUM_TRADE_DIR dir) {
    double high[], low[], close[];
    if(CopyHigh(InpSymbol, PERIOD_M5, 0, 25, high) <= 0) return false;
    if(CopyLow(InpSymbol, PERIOD_M5, 0, 25, low) <= 0) return false;
    if(CopyClose(InpSymbol, PERIOD_M5, 0, 25, close) <= 0) return false;
    
    if(dir == DIR_BUY) {
        // Find recent lower highs
        double recentLH = -1;
        for(int i = 2; i < 20; i++) {
            if(high[i] > high[i-1] && high[i] > high[i+1]) {
                if(recentLH < 0 || high[i] < recentLH) {
                    recentLH = high[i];
                }
            }
        }
        if(recentLH < 0) return false;
        
        // Check if broken
        return (close[0] > recentLH || close[1] > recentLH);
    } else {
        double recentHL = DBL_MAX;
        for(int i = 2; i < 20; i++) {
            if(low[i] < low[i-1] && low[i] < low[i+1]) {
                if(recentHL == DBL_MAX || low[i] > recentHL) {
                    recentHL = low[i];
                }
            }
        }
        if(recentHL == DBL_MAX) return false;
        
        return (close[0] < recentHL || close[1] < recentHL);
    }
}

double CalculateConfidence(SMCResult &r) {
    double conf = 0;
    
    if(r.hasOB) conf += 18;
    if(r.hasFVG) conf += 12;
    if(r.hasVolSpike) conf += 10;
    if(r.hasDivergence) conf += 12;
    if(r.hasADX) conf += 12 * MathMin(r.adxValue / 50.0, 1.0);
    if(r.dxyConfirmed) conf += 8;
    if(r.deltaPositive) conf += 6;
    if(r.vpZoneValid) conf += 5;
    if(r.hasLiqSweep) conf += 7;
    if(r.hasDisplacement) conf += 8;
    if(r.hasBreakerBlock) conf += 6;
    if(r.hasAbsorption) conf += 4;
    if(r.hasSessionMomentum) conf += 4;
    
    return MathMin(conf, 100);
}

//+------------------------------------------------------------------+
//| ENGINE 2 HELPER FUNCTIONS                                        |
//+------------------------------------------------------------------+

void BuildAsiaRange(RevResult &r) {
    ZeroMemory(gAsiaRange);
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    datetime startTime = StringToTime(StringFormat("%04d.%02d.%02d %02d:00:00", 
                               dt.year, dt.mon, dt.day, InpAsiaOpen));
    datetime endTime = startTime + InpAsiaRangeHrs * 3600;
    
    double high[], low[];
    if(CopyHigh(InpSymbol, PERIOD_M5, startTime, endTime, high) <= 0) return;
    if(CopyLow(InpSymbol, PERIOD_M5, startTime, endTime, low) <= 0) return;
    
    int size = MathMin(ArraySize(high), ArraySize(low));
    if(size < 6) return;
    
    double hiVal = high[ArrayMaximum(high, 0, size)];
    double loVal = low[ArrayMinimum(low, 0, size)];
    double pip = GetPipSize(InpSymbol);
    double rangeSize = (hiVal - loVal) / pip;
    
    if(rangeSize < InpE2MinRange) return;
    
    gAsiaRange.hi = hiVal;
    gAsiaRange.lo = loVal;
    gAsiaRange.mid = (hiVal + loVal) / 2;
    gAsiaRange.sizePips = rangeSize;
    gAsiaRange.builtDate = startTime;
    gAsiaRange.isValid = true;
    
    r.c1RangeValid = true;
}

void DetectSweep(RevResult &r) {
    if(!gAsiaRange.isValid) return;
    
    double high[], low[], close[], open[];
    if(CopyHigh(InpSymbol, PERIOD_M5, 0, 15, high) <= 0) return;
    if(CopyLow(InpSymbol, PERIOD_M5, 0, 15, low) <= 0) return;
    if(CopyClose(InpSymbol, PERIOD_M5, 0, 15, close) <= 0) return;
    if(CopyOpen(InpSymbol, PERIOD_M5, 0, 15, open) <= 0) return;
    
    double pip = GetPipSize(InpSymbol);
    double minSweep = InpE2SweepPips * pip;
    
    for(int i = 1; i < InpE2RejBars + 1; i++) {
        // High sweep
        if(high[i] > gAsiaRange.hi + minSweep && 
           close[i] <= gAsiaRange.hi && !gAsiaRange.hiSwept) {
            gAsiaRange.hiSwept = true;
            r.c2Sweep = true;
            r.direction = DIR_SELL;
            r.sweepLevel = gAsiaRange.hi;
            return;
        }
        
        // Low sweep
        if(low[i] < gAsiaRange.lo - minSweep && 
           close[i] >= gAsiaRange.lo && !gAsiaRange.loSwept) {
            gAsiaRange.loSwept = true;
            r.c2Sweep = true;
            r.direction = DIR_BUY;
            r.sweepLevel = gAsiaRange.lo;
            return;
        }
    }
}

bool CheckVolExhaustion(double sweepLevel) {
    double vol[];
    if(CopyTickVolume(InpSymbol, PERIOD_M5, 0, 30, vol) <= 0) return false;
    
    double avg = 0;
    for(int i = 5; i < 25; i++) avg += vol[i];
    avg /= 20;
    
    return (vol[1] < avg * InpE2VolExhaust);
}

bool CheckRejection(ENUM_TRADE_DIR dir) {
    double high[], low[], close[], open[];
    if(CopyHigh(InpSymbol, PERIOD_M5, 0, 10, high) <= 0) return false;
    if(CopyLow(InpSymbol, PERIOD_M5, 0, 10, low) <= 0) return false;
    if(CopyClose(InpSymbol, PERIOD_M5, 0, 10, close) <= 0) return false;
    if(CopyOpen(InpSymbol, PERIOD_M5, 0, 10, open) <= 0) return false;
    
    double pip = GetPipSize(InpSymbol);
    
    for(int i = 1; i < 6; i++) {
        double range = high[i] - low[i];
        if(range < pip * 2) continue;
        
        double upWick = high[i] - MathMax(close[i], open[i]);
        double dnWick = MathMin(close[i], open[i]) - low[i];
        
        if(dir == DIR_BUY) {
            if(dnWick / range * 100 >= InpE2PinbarPct && close[i] > open[i]) {
                return true;
            }
        } else {
            if(upWick / range * 100 >= InpE2PinbarPct && close[i] < open[i]) {
                return true;
            }
        }
    }
    
    return false;
}

bool CheckRSIExtreme(ENUM_TRADE_DIR dir) {
    double rsi[];
    int handle = iRSI(InpSymbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
    if(handle == INVALID_HANDLE) return false;
    if(CopyBuffer(handle, 0, 0, 10, rsi) <= 0) {
        IndicatorRelease(handle);
        return false;
    }
    IndicatorRelease(handle);
    
    if(dir == DIR_BUY) {
        return (rsi[1] <= InpE2RSIOS || rsi[0] <= InpE2RSIOS + 8);
    } else {
        return (rsi[1] >= InpE2RSIOB || rsi[0] >= InpE2RSIOB - 8);
    }
}

double CalculateE2TP(ENUM_TRADE_DIR dir, double entry) {
    double pip = GetPipSize(InpSymbol);
    double vwap = CalculateVWAP();
    
    if(vwap > 0) {
        double dist = MathAbs(vwap - entry) / pip;
        if(dist >= InpE2TPMin && dist <= InpE2TPMax) {
            if(dir == DIR_BUY && vwap > entry) return vwap;
            if(dir == DIR_SELL && vwap < entry) return vwap;
        }
    }
    
    // Fallback to SMA
    double sma[];
    int handle = iMA(InpSymbol, PERIOD_M5, 20, 0, MODE_SMA, PRICE_CLOSE);
    if(handle != INVALID_HANDLE) {
        if(CopyBuffer(handle, 0, 0, 1, sma) > 0) {
            double dist = MathAbs(sma[0] - entry) / pip;
            if(dist >= InpE2TPMin && dist <= InpE2TPMax) {
                if(dir == DIR_BUY && sma[0] > entry) {
                    IndicatorRelease(handle);
                    return sma[0];
                }
                if(dir == DIR_SELL && sma[0] < entry) {
                    IndicatorRelease(handle);
                    return sma[0];
                }
            }
        }
        IndicatorRelease(handle);
    }
    
    // Last resort
    return entry + (dir == DIR_BUY ? 1 : -1) * InpE2TPMin * pip;
}

double CalculateVWAP() {
    double high[], low[], close[], vol[];
    if(CopyHigh(InpSymbol, PERIOD_M5, 0, 100, high) <= 0) return 0;
    if(CopyLow(InpSymbol, PERIOD_M5, 0, 100, low) <= 0) return 0;
    if(CopyClose(InpSymbol, PERIOD_M5, 0, 100, close) <= 0) return 0;
    if(CopyTickVolume(InpSymbol, PERIOD_M5, 0, 100, vol) <= 0) return 0;
    
    double typical[], cumTyp = 0, cumVol = 0;
    ArrayResize(typical, ArraySize(high));
    
    for(int i = 0; i < ArraySize(high); i++) {
        typical[i] = (high[i] + low[i] + close[i]) / 3.0;
        cumTyp += typical[i] * vol[i];
        cumVol += vol[i];
    }
    
    if(cumVol <= 0) return 0;
    return cumTyp / cumVol;
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                 |
//+------------------------------------------------------------------+

double CalculateLot(string symbol, double slPips) {
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
    
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double volMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double volMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    if(tickSize <= 0 || tickValue <= 0 || slPips <= 0) return volMin;
    
    double pipSize = GetPipSize(symbol);
    double lot = riskAmount / (slPips * pipSize / tickSize * tickValue);
    
    if(lot < volMin) lot = volMin;
    if(lot > volMax) lot = volMax;
    lot = MathRound(lot / volStep) * volStep;
    
    return lot;
}

bool OpenTrade(string symbol, ENUM_TRADE_DIR dir, double lot, 
               double sl, double tp1, double tp2, string comment) {
    
    ENUM_ORDER_TYPE type = (dir == DIR_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    double price = SymbolInfoDouble(symbol, 
                 (dir == DIR_BUY) ? SYMBOL_ASK : SYMBOL_BID);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lot;
    request.type = type;
    request.price = price;
    request.sl = sl;
    request.tp = tp1; // Use TP1 initially
    request.deviation = InpMaxSlippage;
    request.magic = InpMagic;
    request.comment = comment;
    request.type_time = ORDER_TIME_GTC;
    request.type_filling = ORDER_FILLING_FOK;
    
    bool success = OrderSend(request, result);
    
    if(!success || result.retcode != TRADE_RETCODE_DONE) {
        PrintR("ORDER FAILED: ", result.retcode, " - ", result.comment);
        return false;
    }
    
    // Modify to add TP2
    if(tp2 > 0 && result.order > 0) {
        ModifyTP(result.order, tp2);
    }
    
    return true;
}

bool ModifySL(long ticket, double newSL) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.sl = newSL;
    request.tp = PositionGetDouble(POSITION_TP);
    request.deviation = InpMaxSlippage;
    
    return OrderSend(request, result);
}

bool ModifyTP(long ticket, double newTP) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.sl = PositionGetDouble(POSITION_SL);
    request.tp = newTP;
    request.deviation = InpMaxSlippage;
    
    return OrderSend(request, result);
}

bool ClosePartial(long ticket, double volume) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double price = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),
                  (posType == POSITION_TYPE_BUY) ? SYMBOL_BID : SYMBOL_ASK);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.volume = volume;
    request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = price;
    request.position = ticket;
    request.deviation = InpMaxSlippage;
    request.magic = InpMagic;
    request.comment = "PARTIAL";
    request.type_time = ORDER_TIME_GTC;
    request.type_filling = ORDER_FILLING_FOK;
    
    return OrderSend(request, result);
}

bool PositionSelectByTicket(long ticket) {
    return PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+
void PrintR(string msg) {
    Print("[", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), "] ", msg);
}

void PrintR(string msg, double val) {
    Print("[", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), "] ", msg, " ", DoubleToString(val, 5));
}

void PrintR(string msg, double val1, string txt, double val2) {
    Print("[", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), "] ", msg, " ", 
          DoubleToString(val1, 5), " ", txt, " ", DoubleToString(val2, 5));
}

void PrintR(string msg1, string msg2) {
    Print("[", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), "] ", msg1, " ", msg2);
}
//+------------------------------------------------------------------+
