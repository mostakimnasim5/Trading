//+------------------------------------------------------------------+
//|                    InstitutionalTraderEA_Advanced.mq5              |
//|                   Professional Trading System v3.0                  |
//|               20 Years Experience | Neural Adaptive Engine          |
//+------------------------------------------------------------------+
#property copyright "Professional Trading System v3.0"
#property version   "3.0"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Arrays/ArrayInt.mqh>

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_TRADE_MODE
{
    TRADE_MODE_TREND      = 0,  // Trend/SMC during kill zones
    TRADE_MODE_MEAN_REV   = 1,  // Mean reversion off-sessions
    TRADE_MODE_BOTH       = 2   // Both modes active
};

enum ENUM_SIGNAL_QUALITY
{
    SIGNAL_WEAK          = 0,
    SIGNAL_MODERATE      = 1,
    SIGNAL_STRONG        = 2,
    SIGNAL_VERY_STRONG   = 3
};

enum ENUM_SESSION
{
    SESSION_ASIAN        = 0,
    SESSION_LONDON       = 1,
    SESSION_NEW_YORK     = 2,
    SESSION_DEAD_ZONE   = 3
};

enum ENUM_MARKET_REGIME
{
    REGIME_UNKNOWN       = 0,
    REGIME_TRENDING_UP   = 1,
    REGIME_TRENDING_DOWN = 2,
    REGIME_RANGING       = 3,
    REGIME_VOLATILE      = 4,
    REGIME_CALM          = 5
};

enum ENUM_TREND_DIRECTION
{
    DIRECTION_NONE       = 0,
    DIRECTION_UP         = 1,
    DIRECTION_DOWN       = 2,
    DIRECTION_REVERSAL_UP = 3,
    DIRECTION_REVERSAL_DOWN = 4
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - SYMBOL & BASIC                               |
//+------------------------------------------------------------------+
input group "===== SYMBOL & BASIC ====="
input string   InpSymbol = "EURUSD";               // Trading Symbol
input ENUM_TRADE_MODE InpTradeMode = TRADE_MODE_BOTH; // Trading Mode
input ulong    InpMagicNumber = 2025003;            // Magic Number

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - RISK MANAGEMENT                               |
//+------------------------------------------------------------------+
input group "===== RISK MANAGEMENT ====="
input double   InpRiskPercent = 1.0;               // Risk Per Trade (%)
input double   InpFixedLot = 0.0;                  // Fixed Lot (0 = use risk %)
input double   InpMaxSpread = 25;                  // Maximum Spread (points)
input int      InpMaxSlippage = 30;                // Maximum Slippage (points)
input double   InpDailyLossLimit = 5.0;            // Daily Loss Limit (%)
input int      InpMaxConsecutiveLoss = 5;           // Max Consecutive Losses
input int      InpMaxGlobalTrades = 3;             // Max Global Trades Per Day
input int      InpCooldownMinutes = 15;             // Cooldown After Trade (min)
input double   InpMinTradeDistance = 50;            // Min Distance from Price (points)
input bool     InpAdaptiveRisk = true;              // Adaptive Risk Based on Regime
input double   InpBaseRiskMultiplier = 1.0;         // Base Risk Multiplier

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - ADAPTIVE NEURAL ENGINE                        |
//+------------------------------------------------------------------+
input group "===== ADAPTIVE NEURAL ENGINE ====="
input bool     InpUseAdaptiveEngine = true;        // Enable Adaptive Neural Engine
input int      InpLearningPeriod = 100;            // Learning Period (candles)
input int      InpLookbackPeriod = 20;             // Lookback for Pattern Analysis
input double   InpMinConfidenceScore = 60;          // Minimum Confidence Score (%)
input int      InpMinConfirmations = 3;            // Minimum Required Confirmations
input double   InpRegimeChangeThreshold = 0.3;    // Regime Change Sensitivity

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - SESSION TIMES                                 |
//+------------------------------------------------------------------+
input group "===== SESSION TIMES ====="
input int      InpAsianStartHour = 0;              // Asian Session Start Hour (GMT)
input int      InpAsianEndHour = 9;               // Asian Session End Hour (GMT)
input int      InpLondonStartHour = 7;             // London Session Start Hour (GMT)
input int      InpLondonEndHour = 11;             // London Session End Hour (GMT)
input int      InpNewYorkStartHour = 12;           // New York Session Start Hour (GMT)
input int      InpNewYorkEndHour = 16;             // New York Session End Hour (GMT)
input int      InpDeadZoneStartHour = 16;          // Dead Zone Start Hour (GMT)
input int      InpDeadZoneEndHour = 21;             // Dead Zone End Hour (GMT)

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - TREND ENGINE SETTINGS                        |
//+------------------------------------------------------------------+
input group "===== TREND ENGINE (SMC) ====="
input bool     InpUseTrendEngine = true;           // Enable Trend Engine
input int      InpTrendTimeframe = 5;              // Trend Timeframe (minutes)
input int      InpHTFConfirm = 60;                  // Higher TF Confirmation (minutes)
input int      InpADXPeriod = 14;                  // ADX Period
input double   InpADXMinStrength = 25;             // ADX Minimum Strength
input int      InpRSIPeriod = 14;                  // RSI Period
input double   InpRSIOverbought = 70;              // RSI Overbought Level
input double   InpRSIOversold = 30;               // RSI Oversold Level
input int      InpMACDFast = 12;                   // MACD Fast EMA
input int      InpMACDSlow = 26;                   // MACD Slow EMA
input int      InpMACDSignal = 9;                  // MACD Signal
input int      InpStochPeriod = 14;                // Stochastic Period
input int      InpStochSmoothK = 3;               // Stochastic Smooth K
input int      InpStochSmoothD = 3;               // Stochastic Smooth D

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - ATR & VOLATILITY                              |
//+------------------------------------------------------------------+
input group "===== ATR & VOLATILITY ====="
input int      InpATRPeriod = 14;                  // ATR Period
input double   InpATRSLMultiplier = 1.5;           // ATR SL Multiplier
input double   InpATRTPMultiplier = 2.5;          // ATR TP Multiplier
input double   InpMinVolatility = 10;              // Min ATR Value for Trade
input double   InpMaxVolatility = 500;             // Max ATR Value for Trade
input double   InpVolatilityBoost = 1.2;            // Volatility SL Boost

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - VOLUME SETTINGS                               |
//+------------------------------------------------------------------+
input group "===== VOLUME SETTINGS ====="
input int      InpVolumePeriod = 20;               // Volume MA Period
input double   InpVolumeSpikeMultiplier = 2.0;      // Volume Spike Threshold
input bool     InpUseVolumeFilter = true;           // Use Volume Filter
input bool     InpUseVolumeProfile = true;          // Use Volume Profile
input int      InpVolumeProfilePeriod = 50;         // Volume Profile Period

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - BOLLINGER BAND (MEAN REV)                     |
//+------------------------------------------------------------------+
input group "===== BOLLINGER BAND (MEAN REVERSION) ====="
input bool     InpUseMeanRevEngine = true;         // Enable Mean Reversion Engine
input int      InpBBPeriod = 20;                   // Bollinger Period
input double   InpBBDeviation = 2.0;               // Bollinger Deviation
input int      InpBBTimeframe = 5;                 // BB Timeframe
input double   InpBBPercentB = 0.5;                // BB Percent B Threshold

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - VWAP & MARKET STRUCTURE                       |
//+------------------------------------------------------------------+
input group "===== VWAP & MARKET STRUCTURE ====="
input bool     InpUseVWAP = true;                  // Use VWAP
input int      InpVWAPSession = 1;                 // VWAP Session (0=Day, 1=Week)
input bool     InpUseMarketStructure = true;        // Use Market Structure
input bool     InpUseOrderBlocks = true;           // Detect Order Blocks
input bool     InpUseFVG = true;                   // Detect Fair Value Gaps
input bool     InpUseLiquiditySweep = true;       // Detect Liquidity Sweeps

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - MULTI-TIMEFRAME ANALYSIS                     |
//+------------------------------------------------------------------+
input group "===== MULTI-TIMEFRAME ANALYSIS ====="
input bool     InpUseMTFAnalysis = true;           // Use Multi-Timeframe Analysis
input int      InpMTFWeightM5 = 1.0;              // Weight M5
input int      InpMTFWeightM15 = 2.0;              // Weight M15
input int      InpMTFWeightH1 = 3.0;               // Weight H1
input int      InpMTFWeightH4 = 4.0;               // Weight H4

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - FILTERS                                      |
//+------------------------------------------------------------------+
input group "===== FILTERS ====="
input bool     InpUseDXYFilter = false;            // Use DXY Correlation Filter
input string   InpDXYSymbol = "DXY";              // DXY Symbol
input bool     InpUseVIXFilter = false;            // Use VIX Filter
input bool     InpUseTrendFilter = true;           // Use Trend Filter
input bool     InpUseCorrelationFilter = false;    // Use Correlation Filter
input string   InpCorrSymbol = "XAUUSD";          // Correlation Symbol

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - EXIT MANAGEMENT                               |
//+------------------------------------------------------------------+
input group "===== EXIT MANAGEMENT ====="
input double   InpBreakEvenTrigger = 1.0;          // Break-Even Trigger (ATR multiples)
input double   InpBreakEvenBuffer = 0.5;           // Break-Even Buffer (ATR)
input bool     InpUsePartialClose = true;           // Use Partial Close
input double   InpPartialClosePercent = 50;        // Partial Close Percentage
input double   InpTP1Percent = 50;                // TP1 Distance (%)
input bool     InpUseTrailingStop = true;           // Use Trailing Stop
input double   InpTrailStartPercent = 50;          // Trail Start After TP%
input double   InpTrailDistancePercent = 30;        // Trail Distance %
input bool     InpUseSmartExit = true;             // Smart Exit on Reversal

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - DEBUG & LOGGING                               |
//+------------------------------------------------------------------+
input group "===== DEBUG & LOGGING ====="
input bool     InpDebugMode = false;               // Enable Debug Mode
input bool     InpVerboseLogging = true;            // Verbose Trade Logging
input bool     InpLogSignals = true;               // Log All Signals

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade          g_trade;                           // Trading class
datetime        g_lastTradeTime = 0;               // Last trade timestamp
datetime        g_lastCandleTime = 0;               // Last processed candle
datetime        g_lastDailyReset = 0;              // Last daily reset time
ENUM_SESSION    g_currentSession = SESSION_ASIAN;   // Current trading session
ENUM_MARKET_REGIME g_currentRegime = REGIME_UNKNOWN; // Current market regime

//+------------------------------------------------------------------+
//| ADAPTIVE LEARNING VARIABLES                                      |
//+------------------------------------------------------------------+
double          g_winRate = 0.5;                   // Calculated win rate
double          g_avgWin = 0;                      // Average win amount
double          g_avgLoss = 0;                     // Average loss amount
double          g_sharpeRatio = 0;                 // Sharpe ratio estimate
double          g_regimeStrength = 0;              // Regime detection confidence
double          g_adaptiveConfidence = 50;         // Neural confidence score
int             g_consecutiveLosses = 0;            // Consecutive losses counter
double          g_recentPerformance[];              // Recent trade performance
int             g_performanceIndex = 0;             // Circular buffer index

//+------------------------------------------------------------------+
//| NEURAL SIGNAL BUFFER                                            |
//+------------------------------------------------------------------+
double          g_neuralWeights[];                 // Neural network weights
double          g_signalHistory[];                  // Historical signal accuracy
double          g_marketMemory[];                   // Market pattern memory

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct STradeSignal
{
    ENUM_TRADE_MODE    mode;
    ENUM_SIGNAL_QUALITY quality;
    double             confidence;
    int                confirmations;
    bool               buySignal;
    bool               sellSignal;
    double             entryPrice;
    double             stopLoss;
    double             takeProfit;
    double             neuralScore;
    double             regimeConfidence;
    ENUM_MARKET_REGIME detectedRegime;
    ENUM_TREND_DIRECTION trendDirection;
    string             description;
    datetime           timestamp;
};

struct SMarketData
{
    double             price;
    double             high;
    double             low;
    double             volume;
    double             volatility;
    double             trendStrength;
    double             momentum;
    double             vwap;
    double             volumeProfileHigh;
    double             volumeProfileLow;
};

struct SMomentumIndicators
{
    double             rsi;
    double             stochastic;
    double             macd;
    double             adx;
    double             momentumOscillator;
    double             roc; // Rate of Change
};

struct SLearningData
{
    double             expectedReturn;
    double             riskScore;
    double             confidence;
    double             regimeFit;
    double             finalScore;
};

//+------------------------------------------------------------------+
//| INDICATOR HANDLES                                                |
//+------------------------------------------------------------------+
int g_handleADX = INVALID_HANDLE;
int g_handleRSI = INVALID_HANDLE;
int g_handleMACD = INVALID_HANDLE;
int g_handleATR = INVALID_HANDLE;
int g_handleBB = INVALID_HANDLE;
int g_handleVolumeMA = INVALID_HANDLE;
int g_handleMA = INVALID_HANDLE;
int g_handleStoch = INVALID_HANDLE;
int g_handleMomentum = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize adaptive arrays
    ArrayResize(g_recentPerformance, InpLearningPeriod);
    ArrayResize(g_neuralWeights, InpLearningPeriod);
    ArrayResize(g_signalHistory, InpLearningPeriod);
    ArrayResize(g_marketMemory, InpLearningPeriod);
    ArrayInitialize(g_recentPerformance, 0);
    ArrayInitialize(g_neuralWeights, 0.5);
    ArrayInitialize(g_signalHistory, 0.5);
    ArrayInitialize(g_marketMemory, 0);
    
    // Reset tracking
    g_lastDailyReset = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    g_winRate = 0.5;
    g_avgWin = 0;
    g_avgLoss = 0;
    
    // Initialize trading class
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetMarginMode();
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    g_trade.SetDeviationInPoints(InpMaxSlippage);
    
    // Initialize indicator handles
    if(!InitIndicators())
    {
        Print("ERROR: Failed to initialize indicators");
        return INIT_FAILED;
    }
    
    // Initialize neural engine
    if(InpUseAdaptiveEngine)
    {
        InitializeNeuralEngine();
    }
    
    Print("===========================================");
    Print("InstitutionalTraderEA Advanced v3.0");
    Print("Symbol: ", InpSymbol);
    Print("Adaptive Neural Engine: ", InpUseAdaptiveEngine ? "ENABLED" : "DISABLED");
    Print("Risk Per Trade: ", DoubleToString(InpRiskPercent, 2), "%");
    Print("Learning Period: ", InpLearningPeriod, " candles");
    Print("===========================================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ReleaseIndicators();
    
    string reasonText = "";
    switch(reason)
    {
        case REASON_PROGRAM:     reasonText = "Program terminated"; break;
        case REASON_REMOVE:      reasonText = "EA removed from chart"; break;
        case REASON_RECOMPILE:   reasonText = "EA recompiled"; break;
        case REASON_CHARTCHANGE: reasonText = "Symbol/timeframe changed"; break;
        case REASON_CHARTCLOSE:  reasonText = "Chart closed"; break;
        case REASON_PARAMETERS:  reasonText = "Input parameters changed"; break;
        case REASON_ACCOUNT:     reasonText = "Account changed"; break;
        default:                 reasonText = "Unknown reason"; break;
    }
    
    if(InpDebugMode)
        Print("EA Deinitialized: ", reasonText);
}

//+------------------------------------------------------------------+
//| INITIALIZE NEURAL ENGINE                                         |
//+------------------------------------------------------------------+
void InitializeNeuralEngine()
{
    // Initialize neural weights with small random values
    MathSrand(GetTickCount());
    for(int i = 0; i < InpLearningPeriod; i++)
    {
        g_neuralWeights[i] = 0.3 + (MathRand() / 32767.0) * 0.4; // 0.3 to 0.7
        g_signalHistory[i] = 0.5;
    }
    
    if(InpDebugMode)
        Print("Neural Engine Initialized with ", InpLearningPeriod, " weights");
}

//+------------------------------------------------------------------+
//| INDICATOR INITIALIZATION                                         |
//+------------------------------------------------------------------+
bool InitIndicators()
{
    // ADX Indicator
    g_handleADX = iADX(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpADXPeriod);
    if(g_handleADX == INVALID_HANDLE) { Print("ERROR: ADX handle"); return false; }
    
    // RSI Indicator
    g_handleRSI = iRSI(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpRSIPeriod, PRICE_CLOSE);
    if(g_handleRSI == INVALID_HANDLE) { Print("ERROR: RSI handle"); return false; }
    
    // MACD Indicator
    g_handleMACD = iMACD(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
    if(g_handleMACD == INVALID_HANDLE) { Print("ERROR: MACD handle"); return false; }
    
    // ATR Indicator
    g_handleATR = iATR(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpATRPeriod);
    if(g_handleATR == INVALID_HANDLE) { Print("ERROR: ATR handle"); return false; }
    
    // Bollinger Bands
    g_handleBB = iBands(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    if(g_handleBB == INVALID_HANDLE) { Print("ERROR: BB handle"); return false; }
    
    // Volume Moving Average
    g_handleVolumeMA = iMA(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpVolumePeriod, 0, MODE_SMA, VOLUME_TICK);
    if(g_handleVolumeMA == INVALID_HANDLE) { Print("ERROR: VolumeMA handle"); return false; }
    
    // Moving Average for trend
    g_handleMA = iMA(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(g_handleMA == INVALID_HANDLE) { Print("ERROR: MA handle"); return false; }
    
    // Stochastic Oscillator
    g_handleStoch = iStochastic(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpStochPeriod, InpStochSmoothK, InpStochSmoothD, MODE_SMA, STO_LOWHIGH);
    if(g_handleStoch == INVALID_HANDLE) { Print("ERROR: Stoch handle"); return false; }
    
    // Momentum Indicator
    g_handleMomentum = iMomentum(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 14, PRICE_CLOSE);
    if(g_handleMomentum == INVALID_HANDLE) { Print("ERROR: Momentum handle"); return false; }
    
    return true;
}

//+------------------------------------------------------------------+
//| RELEASE INDICATOR HANDLES                                        |
//+------------------------------------------------------------------+
void ReleaseIndicators()
{
    if(g_handleADX != INVALID_HANDLE) IndicatorRelease(g_handleADX);
    if(g_handleRSI != INVALID_HANDLE) IndicatorRelease(g_handleRSI);
    if(g_handleMACD != INVALID_HANDLE) IndicatorRelease(g_handleMACD);
    if(g_handleATR != INVALID_HANDLE) IndicatorRelease(g_handleATR);
    if(g_handleBB != INVALID_HANDLE) IndicatorRelease(g_handleBB);
    if(g_handleVolumeMA != INVALID_HANDLE) IndicatorRelease(g_handleVolumeMA);
    if(g_handleMA != INVALID_HANDLE) IndicatorRelease(g_handleMA);
    if(g_handleStoch != INVALID_HANDLE) IndicatorRelease(g_handleStoch);
    if(g_handleMomentum != INVALID_HANDLE) IndicatorRelease(g_handleMomentum);
}

//+------------------------------------------------------------------+
//| MAIN TICK FUNCTION                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new candle
    datetime currentCandleTime = iTime(InpSymbol, PERIOD_CURRENT, 0);
    if(currentCandleTime == g_lastCandleTime)
        return;
    g_lastCandleTime = currentCandleTime;
    
    // Daily reset check
    CheckDailyReset();
    
    // Validate market conditions
    if(!ValidateMarketConditions())
        return;
    
    // Update current session
    UpdateSessionInfo();
    
    // Detect market regime (Adaptive)
    ENUM_MARKET_REGIME newRegime = DetectMarketRegime();
    if(newRegime != g_currentRegime)
    {
        g_currentRegime = newRegime;
        if(InpDebugMode)
            Print("Regime Changed to: ", EnumToString(newRegime));
    }
    
    // Update adaptive learning
    if(InpUseAdaptiveEngine)
    {
        UpdateAdaptiveLearning();
    }
    
    // Check for existing positions
    if(HasOpenPosition())
    {
        ManageOpenTrade();
        return;
    }
    
    // Check cooldown
    if(IsInCooldown())
        return;
    
    // Check daily/global limits
    if(!CheckTradingLimits())
        return;
    
    // Generate trading signal
    STradeSignal signal;
    ZeroMemory(signal);
    
    // Get base signals from both engines
    STradeSignal trendSignal = DetectTrendSignal();
    STradeSignal meanRevSignal = DetectMeanRevSignal();
    
    // Select best signal based on regime
    signal = SelectBestSignal(trendSignal, meanRevSignal);
    
    // Apply neural enhancement
    if(InpUseAdaptiveEngine && (signal.buySignal || signal.sellSignal))
    {
        ApplyNeuralEnhancement(signal);
    }
    
    // Execute trade if signal is strong enough
    if(signal.confidence >= InpMinConfidenceScore && signal.confirmations >= InpMinConfirmations)
    {
        if(InpLogSignals)
        {
            Print("SIGNAL: ", signal.description, " Confidence: ", DoubleToString(signal.confidence, 1), 
                  "% Neural: ", DoubleToString(signal.neuralScore, 2));
        }
        ExecuteTrade(signal);
    }
}

//+------------------------------------------------------------------+
//| DETECT MARKET REGIME (ADAPTIVE)                                  |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME DetectMarketRegime()
{
    // Get multiple indicators for regime detection
    double adxValue, adxPlus, adxMinus;
    double atrValue;
    double close[];
    double volume[], volumeMA[];
    
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(volume, true);
    ArraySetAsSeries(volumeMA, true);
    
    if(CopyBuffer(g_handleADX, 0, 0, 5, adxValue) <= 0) return REGIME_UNKNOWN;
    if(CopyBuffer(g_handleADX, 1, 0, 5, adxPlus) <= 0) return REGIME_UNKNOWN;
    if(CopyBuffer(g_handleADX, 2, 0, 5, adxMinus) <= 0) return REGIME_UNKNOWN;
    if(CopyBuffer(g_handleATR, 0, 0, 5, atrValue) <= 0) return REGIME_UNKNOWN;
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, close) <= 0) return REGIME_UNKNOWN;
    if(CopyBuffer(g_handleVolumeMA, 0, 0, 5, volumeMA) <= 0) return REGIME_UNKNOWN;
    if(CopyTickVolume(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, volume) <= 0) return REGIME_UNKNOWN;
    
    // Check for NaN
    if(!MathIsValidNumber(adxValue) || !MathIsValidNumber(atrValue) || !MathIsValidNumber(close[0]))
        return REGIME_UNKNOWN;
    
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    
    // Calculate volatility ratio
    double atrCurrent = atrValue / point;
    double atrAvg;
    int atrMaHandle = iMA(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 20, 0, MODE_SMA, PRICE_CLOSE);
    if(atrMaHandle != INVALID_HANDLE)
    {
        double atrBuffer[];
        ArraySetAsSeries(atrBuffer, true);
        if(CopyBuffer(atrMaHandle, 0, 0, 5, atrBuffer) > 0)
        {
            atrAvg = atrBuffer[0] / point;
        }
        IndicatorRelease(atrMaHandle);
    }
    else
    {
        atrAvg = atrCurrent;
    }
    
    double volatilityRatio = (atrAvg > 0) ? atrCurrent / atrAvg : 1.0;
    
    // Calculate trend strength
    double adxStrength = adxValue;
    double plusDM = adxPlus;
    double minusDM = adxMinus;
    bool upTrend = (plusDM > minusDM);
    bool downTrend = (minusDM > plusDM);
    
    // Calculate volume ratio
    double volumeRatio = (volumeMA[0] > 0) ? volume[0] / volumeMA[0] : 1.0;
    
    // Detect regime based on multiple factors
    ENUM_MARKET_REGIME regime = REGIME_RANGING;
    g_regimeStrength = 0;
    
    // Strong Trending Up
    if(adxStrength > InpADXMinStrength * 1.5 && upTrend && volatilityRatio < 1.5)
    {
        regime = REGIME_TRENDING_UP;
        g_regimeStrength = MathMin(adxStrength / 50.0, 1.0);
    }
    // Strong Trending Down
    else if(adxStrength > InpADXMinStrength * 1.5 && downTrend && volatilityRatio < 1.5)
    {
        regime = REGIME_TRENDING_DOWN;
        g_regimeStrength = MathMin(adxStrength / 50.0, 1.0);
    }
    // Volatile Market
    else if(volatilityRatio > 2.0 || volumeRatio > 3.0)
    {
        regime = REGIME_VOLATILE;
        g_regimeStrength = MathMin(volatilityRatio / 3.0, 1.0);
    }
    // Calm Market
    else if(volatilityRatio < 0.5 && volumeRatio < 0.5 && adxStrength < 20)
    {
        regime = REGIME_CALM;
        g_regimeStrength = 0.8;
    }
    // Ranging
    else
    {
        regime = REGIME_RANGING;
        g_regimeStrength = 0.5;
    }
    
    return regime;
}

//+------------------------------------------------------------------+
//| UPDATE ADAPTIVE LEARNING                                         |
//+------------------------------------------------------------------+
void UpdateAdaptiveLearning()
{
    // Update recent performance buffer
    double recentPnL = CalculateRecentPnL();
    
    g_recentPerformance[g_performanceIndex] = recentPnL;
    g_performanceIndex = (g_performanceIndex + 1) % InpLearningPeriod;
    
    // Recalculate win rate
    int wins = 0, total = 0;
    double totalWin = 0, totalLoss = 0;
    
    for(int i = 0; i < InpLearningPeriod; i++)
    {
        if(g_recentPerformance[i] != 0)
        {
            total++;
            if(g_recentPerformance[i] > 0)
            {
                wins++;
                totalWin += g_recentPerformance[i];
            }
            else
            {
                totalLoss += MathAbs(g_recentPerformance[i]);
            }
        }
    }
    
    if(total > 0)
    {
        g_winRate = (double)wins / total;
        if(wins > 0) g_avgWin = totalWin / wins;
        if(total - wins > 0) g_avgLoss = totalLoss / (total - wins);
    }
    
    // Update neural weights based on performance
    UpdateNeuralWeights();
    
    if(InpDebugMode && total % 20 == 0)
    {
        Print("Adaptive Learning - WinRate: ", DoubleToString(g_winRate * 100, 1), 
              "% AvgWin: ", DoubleToString(g_avgWin, 2),
              " AvgLoss: ", DoubleToString(g_avgLoss, 2));
    }
}

//+------------------------------------------------------------------+
//| CALCULATE RECENT P&L                                             |
//+------------------------------------------------------------------+
double CalculateRecentPnL()
{
    double recentPnL = 0;
    datetime recentTime = TimeCurrent() - 3600; // Last 1 hour
    
    HistorySelect(recentTime, TimeCurrent());
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
        {
            recentPnL += HistoryDealGetDouble(ticket, DEAL_PROFIT);
        }
    }
    HistorySelect(0, TimeCurrent());
    
    return recentPnL;
}

//+------------------------------------------------------------------+
//| UPDATE NEURAL WEIGHTS                                            |
//+------------------------------------------------------------------+
void UpdateNeuralWeights()
{
    // Use simple Hebbian learning - strengthen weights that led to wins
    for(int i = 0; i < InpLearningPeriod; i++)
    {
        if(g_recentPerformance[i] > 0)
        {
            // Reinforce winning patterns
            g_neuralWeights[i] = MathMin(g_neuralWeights[i] * 1.05, 1.0);
        }
        else if(g_recentPerformance[i] < 0)
        {
            // Weaken losing patterns
            g_neuralWeights[i] = MathMax(g_neuralWeights[i] * 0.95, 0.1);
        }
        // Decay unused weights
        else
        {
            g_neuralWeights[i] = g_neuralWeights[i] * 0.999 + 0.5 * 0.001;
        }
    }
}

//+------------------------------------------------------------------+
//| APPLY NEURAL ENHANCEMENT                                         |
//+------------------------------------------------------------------+
void ApplyNeuralEnhancement(SStradeSignal &signal)
{
    // Calculate neural score based on pattern matching
    double patternScore = CalculatePatternScore();
    
    // Calculate momentum score
    double momentumScore = CalculateMomentumScore();
    
    // Calculate regime fit score
    double regimeFitScore = CalculateRegimeFitScore(signal);
    
    // Combine scores with weights
    signal.neuralScore = (patternScore * 0.4 + momentumScore * 0.3 + regimeFitScore * 0.3);
    
    // Adjust confidence based on neural score
    signal.confidence = signal.confidence * (0.7 + signal.neuralScore * 0.3);
    
    // Add confidence to description
    signal.description += StringFormat(" Neural[%.1f] ", signal.neuralScore * 100);
    
    // Update regime confidence
    signal.regimeConfidence = g_regimeStrength;
    signal.detectedRegime = g_currentRegime;
}

//+------------------------------------------------------------------+
//| CALCULATE PATTERN SCORE (Neural Pattern Matching)                |
//+------------------------------------------------------------------+
double CalculatePatternScore()
{
    double score = 0.5; // Default neutral
    
    // Get recent price data
    double close[], high[], low[], open[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(open, true);
    
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, InpLookbackPeriod, close) <= 0)
        return score;
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, InpLookbackPeriod, high) <= 0)
        return score;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, InpLookbackPeriod, low) <= 0)
        return score;
    if(CopyOpen(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, InpLookbackPeriod, open) <= 0)
        return score;
    
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    
    // Calculate various pattern metrics
    int patternsFound = 0;
    
    // 1. Higher Highs and Higher Lows (Bullish)
    bool higherHighs = true, higherLows = true;
    for(int i = 1; i < 5; i++)
    {
        if(high[i] <= high[i+1]) higherHighs = false;
        if(low[i] <= low[i+1]) higherLows = false;
    }
    if(higherHighs && higherLows) patternsFound++;
    
    // 2. Lower Highs and Lower Lows (Bearish)
    bool lowerHighs = true, lowerLows = true;
    for(int i = 1; i < 5; i++)
    {
        if(high[i] >= high[i+1]) lowerHighs = false;
        if(low[i] >= low[i+1]) lowerLows = false;
    }
    if(lowerHighs && lowerLows) patternsFound++;
    
    // 3. Doji / Spinning Top detection
    double bodySize = MathAbs(close[0] - open[0]) / point;
    double range = (high[0] - low[0]) / point;
    if(range > 0 && bodySize < range * 0.2) patternsFound++;
    
    // 4. Engulfing patterns
    bool bullishEngulf = (close[1] < open[1]) && (close[0] > open[0]) && 
                         (close[0] > open[1]) && (open[0] < close[1]);
    bool bearishEngulf = (close[1] > open[1]) && (close[0] < open[0]) && 
                        (close[0] < open[1]) && (open[0] > close[1]);
    if(bullishEngulf || bearishEngulf) patternsFound++;
    
    // 5. Pin bar / Rejection candle
    double upperWick = (high[0] - MathMax(open[0], close[0])) / point;
    double lowerWick = (MathMin(open[0], close[0]) - low[0]) / point;
    if((lowerWick > bodySize * 2 && upperWick < bodySize * 0.3) ||
       (upperWick > bodySize * 2 && lowerWick < bodySize * 0.3))
        patternsFound++;
    
    // Normalize score
    score = 0.3 + (patternsFound / 5.0) * 0.5;
    
    // Apply neural weight adjustment
    double weightSum = 0;
    for(int i = 0; i < MathMin(InpLookbackPeriod, InpLearningPeriod); i++)
    {
        weightSum += g_neuralWeights[i];
    }
    double avgWeight = (weightSum / MathMin(InpLookbackPeriod, InpLearningPeriod));
    
    score = score * (0.7 + avgWeight * 0.3);
    
    return MathMax(MathMin(score, 1.0), 0.0);
}

//+------------------------------------------------------------------+
//| CALCULATE MOMENTUM SCORE                                         |
//+------------------------------------------------------------------+
double CalculateMomentumScore()
{
    double score = 0.5;
    
    double rsiValue, stochMain, stochSignal;
    double momentumValue;
    double macdMain[], macdSignal[];
    double adxValue;
    
    ArraySetAsSeries(macdMain, true);
    ArraySetAsSeries(macdSignal, true);
    
    if(CopyBuffer(g_handleRSI, 0, 0, 3, rsiValue) <= 0) return score;
    if(CopyBuffer(g_handleStoch, 0, 0, 3, stochMain) <= 0) return score;
    if(CopyBuffer(g_handleStoch, 1, 0, 3, stochSignal) <= 0) return score;
    if(CopyBuffer(g_handleMomentum, 0, 0, 3, momentumValue) <= 0) return score;
    if(CopyBuffer(g_handleMACD, 0, 0, 3, macdMain) <= 0) return score;
    if(CopyBuffer(g_handleMACD, 1, 0, 3, macdSignal) <= 0) return score;
    if(CopyBuffer(g_handleADX, 0, 0, 3, adxValue) <= 0) return score;
    
    if(!MathIsValidNumber(rsiValue) || !MathIsValidNumber(stochMain))
        return score;
    
    int bullishSignals = 0;
    int totalSignals = 6;
    
    // RSI momentum
    if(rsiValue > 50 && rsiValue < InpRSIOverbought) bullishSignals++;
    else if(rsiValue < 50 && rsiValue > InpRSIOversold) bullishSignals++;
    
    // Stochastic momentum
    if(stochMain > stochSignal && stochMain < 80) bullishSignals++;
    else if(stochMain < stochSignal && stochMain > 20) bullishSignals++;
    
    // MACD momentum
    if(macdMain[0] > macdSignal[0] && macdMain[0] > 0) bullishSignals++;
    else if(macdMain[0] < macdSignal[0] && macdMain[0] < 0) bullishSignals++;
    
    // Momentum indicator
    if(momentumValue > 100) bullishSignals++;
    else if(momentumValue < 100) bullishSignals++;
    
    // ADX trend confirmation
    if(adxValue > 20) bullishSignals++;
    
    // Rate of consistency
    if(MathAbs(macdMain[0] - macdMain[1]) < MathAbs(macdMain[1] - macdMain[2]))
        bullishSignals++;
    
    score = (double)bullishSignals / totalSignals;
    
    return score;
}

//+------------------------------------------------------------------+
//| CALCULATE REGIME FIT SCORE                                       |
//+------------------------------------------------------------------+
double CalculateRegimeFitScore(STradeSignal &signal)
{
    double score = 0.5;
    
    // Regime-specific scoring
    switch(g_currentRegime)
    {
        case REGIME_TRENDING_UP:
            // Favor buy signals in uptrend
            if(signal.buySignal) score = 0.8;
            else if(signal.sellSignal) score = 0.3;
            break;
            
        case REGIME_TRENDING_DOWN:
            // Favor sell signals in downtrend
            if(signal.sellSignal) score = 0.8;
            else if(signal.buySignal) score = 0.3;
            break;
            
        case REGIME_RANGING:
            // Favor mean reversion signals
            if(signal.mode == TRADE_MODE_MEAN_REV) score = 0.8;
            else score = 0.4;
            break;
            
        case REGIME_VOLATILE:
            // Reduce confidence in volatile markets
            score = 0.5 * (1.0 - g_regimeStrength * 0.3);
            break;
            
        case REGIME_CALM:
            // Increase confidence in calm markets
            score = 0.6 + g_regimeStrength * 0.2;
            break;
    }
    
    // Adjust based on regime strength
    score = score * (0.5 + g_regimeStrength * 0.5);
    
    return MathMax(MathMin(score, 1.0), 0.0);
}

//+------------------------------------------------------------------+
//| SELECT BEST SIGNAL                                                |
//+------------------------------------------------------------------+
STradeSignal SelectBestSignal(STradeSignal &trendSignal, STradeSignal &meanRevSignal)
{
    STradeSignal bestSignal;
    ZeroMemory(bestSignal);
    
    // If only one signal exists, return it
    if(trendSignal.confidence == 0 && meanRevSignal.confidence > 0)
        return meanRevSignal;
    if(meanRevSignal.confidence == 0 && trendSignal.confidence > 0)
        return trendSignal;
    if(trendSignal.confidence == 0 && meanRevSignal.confidence == 0)
        return bestSignal;
    
    // Regime-based selection
    double trendWeight = 0.5;
    double meanRevWeight = 0.5;
    
    switch(g_currentRegime)
    {
        case REGIME_TRENDING_UP:
        case REGIME_TRENDING_DOWN:
            trendWeight = 0.7;
            meanRevWeight = 0.3;
            break;
        case REGIME_RANGING:
        case REGIME_CALM:
            trendWeight = 0.3;
            meanRevWeight = 0.7;
            break;
        case REGIME_VOLATILE:
            trendWeight = 0.5;
            meanRevWeight = 0.5;
            break;
    }
    
    // Calculate weighted scores
    double trendScore = trendSignal.confidence * trendWeight;
    double meanRevScore = meanRevSignal.confidence * meanRevWeight;
    
    // Also consider session
    if(g_currentSession == SESSION_LONDON || g_currentSession == SESSION_NEW_YORK)
    {
        // Kill zones favor trend trading
        trendScore *= 1.2;
    }
    else
    {
        // Off-hours favor mean reversion
        meanRevScore *= 1.2;
    }
    
    // Select best
    if(trendScore > meanRevScore)
        bestSignal = trendSignal;
    else
        bestSignal = meanRevSignal;
    
    return bestSignal;
}

//+------------------------------------------------------------------+
//| DETECT TREND SIGNAL (SMC LOGIC)                                  |
//+------------------------------------------------------------------+
STradeSignal DetectTrendSignal()
{
    STradeSignal signal;
    ZeroMemory(signal);
    signal.mode = TRADE_MODE_TREND;
    
    // Get indicator values
    double adxValue;
    double rsiValue;
    double macdMain[], macdSignal[];
    double atrValue;
    double ma50[];
    double volume[], volumeMA[];
    double close[], high[], low[], open[];
    double stochMain[], stochSignal[];
    
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(macdMain, true);
    ArraySetAsSeries(macdSignal, true);
    ArraySetAsSeries(ma50, true);
    ArraySetAsSeries(volume, true);
    ArraySetAsSeries(volumeMA, true);
    ArraySetAsSeries(stochMain, true);
    ArraySetAsSeries(stochSignal, true);
    
    // Copy indicator data
    if(CopyBuffer(g_handleADX, 0, 0, 5, adxValue) <= 0) return signal;
    if(CopyBuffer(g_handleRSI, 0, 0, 5, rsiValue) <= 0) return signal;
    if(CopyBuffer(g_handleMACD, 0, 0, 5, macdMain) <= 0) return signal;
    if(CopyBuffer(g_handleMACD, 1, 0, 5, macdSignal) <= 0) return signal;
    if(CopyBuffer(g_handleATR, 0, 0, 5, atrValue) <= 0) return signal;
    if(CopyBuffer(g_handleVolumeMA, 0, 0, 5, volumeMA) <= 0) return signal;
    if(CopyBuffer(g_handleMA, 0, 0, 5, ma50) <= 0) return signal;
    if(CopyBuffer(g_handleStoch, 0, 0, 5, stochMain) <= 0) return signal;
    if(CopyBuffer(g_handleStoch, 1, 0, 5, stochSignal) <= 0) return signal;
    
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, close) <= 0) return signal;
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, high) <= 0) return signal;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, low) <= 0) return signal;
    if(CopyOpen(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, open) <= 0) return signal;
    if(CopyTickVolume(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, volume) <= 0) return signal;
    
    // Check for NaN
    if(!MathIsValidNumber(adxValue) || !MathIsValidNumber(rsiValue) ||
       !MathIsValidNumber(macdMain[0]) || !MathIsValidNumber(atrValue))
    {
        return signal;
    }
    
    // Get higher timeframe data for confirmation
    double h4MA = 0, h1MA = 0;
    double h4Close[], h1Close[];
    ArraySetAsSeries(h4Close, true);
    ArraySetAsSeries(h1Close, true);
    
    int h4Handle = iMA(InpSymbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(h4Handle != INVALID_HANDLE)
    {
        double h4Buffer[];
        ArraySetAsSeries(h4Buffer, true);
        if(CopyBuffer(h4Handle, 0, 0, 2, h4Buffer) > 0)
            h4MA = h4Buffer[0];
        IndicatorRelease(h4Handle);
    }
    
    int h1Handle = iMA(InpSymbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(h1Handle != INVALID_HANDLE)
    {
        double h1Buffer[];
        ArraySetAsSeries(h1Buffer, true);
        if(CopyBuffer(h1Handle, 0, 0, 2, h1Buffer) > 0)
            h1MA = h1Buffer[0];
        IndicatorRelease(h1Handle);
    }
    
    if(CopyClose(InpSymbol, PERIOD_H4, 0, 2, h4Close) <= 0) return signal;
    if(CopyClose(InpSymbol, PERIOD_H1, 0, 2, h1Close) <= 0) return signal;
    
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    
    // Calculate all indicators
    double volumeSpikeThreshold = volumeMA[0] * InpVolumeSpikeMultiplier;
    bool volumeConfirmed = (volume[0] >= volumeSpikeThreshold);
    bool atrValid = (atrValue >= InpMinVolatility * point) && (atrValue <= InpMaxVolatility * point);
    
    if(!atrValid) return signal;
    
    double atrPoints = atrValue / point;
    
    // ADX confirmation
    bool adxConfirmed = (adxValue >= InpADXMinStrength);
    
    // RSI confirmation
    bool rsiNormal = (rsiValue > InpRSIOversold && rsiValue < InpRSIOverbought);
    bool rsiBullish = (rsiValue > 50);
    bool rsiBearish = (rsiValue < 50);
    
    // MACD confirmation
    double macdHist = macdMain[0] - macdSignal[0];
    double macdHistPrev = macdMain[1] - macdSignal[1];
    bool macdBullish = (macdHist > 0) || (macdHist > macdHistPrev);
    bool macdBearish = (macdHist < 0) || (macdHist < macdHistPrev);
    
    // Stochastic confirmation
    bool stochBullish = (stochMain[0] > stochSignal[0]) && (stochMain[0] < 80);
    bool stochBearish = (stochMain[0] < stochSignal[0]) && (stochMain[0] > 20);
    
    // Volume confirmation
    bool volumeFilterPassed = !InpUseVolumeFilter || volumeConfirmed;
    
    // HTF confirmation
    bool htfBullish = (h4Close[0] > h4MA) && (h1Close[0] > h1MA);
    bool htfBearish = (h4Close[0] < h4MA) && (h1Close[0] < h1MA);
    bool trendFilterPassed = !InpUseTrendFilter || (htfBullish || htfBearish);
    
    // Market structure detection
    bool structureBullish, structureBearish;
    DetectMarketStructure(structureBullish, structureBearish);
    
    // Order block detection
    double obLevel = 0;
    if(InpUseOrderBlocks)
    {
        double obBuy = DetectOrderBlock(true);
        double obSell = DetectOrderBlock(false);
        if(close[0] > obBuy && obBuy > 0) obLevel = obBuy;
        if(close[0] < obSell && obSell > 0) obLevel = obSell;
    }
    
    // FVG detection
    bool bullishFVG = false, bearishFVG = false;
    double fvgMid = 0;
    if(InpUseFVG)
    {
        DetectFairValueGap(bullishFVG, bearishFVG, fvgMid);
    }
    
    // Get prices
    double askPrice = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    
    // Calculate SL/TP
    double slDistance = atrPoints * InpATRSLMultiplier;
    double tpDistance = atrPoints * InpATRTPMultiplier;
    slDistance = MathMax(slDistance, InpMinTradeDistance);
    tpDistance = MathMax(tpDistance, InpMinTradeDistance * 2);
    
    double stopLossBuy = NormalizeDouble(askPrice - slDistance * point, _Digits);
    double takeProfitBuy = NormalizeDouble(askPrice + tpDistance * point, _Digits);
    double stopLossSell = NormalizeDouble(bidPrice + slDistance * point, _Digits);
    double takeProfitSell = NormalizeDouble(bidPrice - tpDistance * point, _Digits);
    
    // Candlestick patterns
    double bodySize = MathAbs(close[0] - open[0]) / point;
    bool bullishCandle = (close[0] > open[0]);
    bool bearishCandle = (close[0] < open[0]);
    bool bullishEngulf = bullishCandle && (close[1] < open[1]) && (close[0] > open[1]) && (open[0] < close[1]);
    bool bearishEngulf = bearishCandle && (close[1] > open[1]) && (close[0] < open[1]) && (open[0] > close[1]);
    
    int confirmations = 0;
    string signalDescription = "";
    
    // BUY SIGNAL
    if(atrValid && adxConfirmed && rsiNormal)
    {
        confirmations = 0;
        signalDescription = "";
        
        if(adxConfirmed) { confirmations++; signalDescription += "ADX "; }
        if(rsiBullish && rsiNormal) { confirmations++; signalDescription += "RSI+ "; }
        if(macdBullish) { confirmations++; signalDescription += "MACD+ "; }
        if(stochBullish) { confirmations++; signalDescription += "Stoch+ "; }
        if(volumeFilterPassed) { confirmations++; signalDescription += "Vol "; }
        if(htfBullish) { confirmations++; signalDescription += "HTF+ "; }
        if(structureBullish) { confirmations++; signalDescription += "Struct "; }
        if(bullishEngulf) { confirmations++; signalDescription += "Engulf "; }
        if(bullishFVG) { confirmations++; signalDescription += "FVG "; }
        
        double confidence = (double)confirmations / 9.0 * 100;
        
        if(confirmations >= InpMinConfirmations)
        {
            signal.buySignal = true;
            signal.sellSignal = false;
            signal.confidence = confidence;
            signal.confirmations = confirmations;
            signal.quality = (confidence >= 80) ? SIGNAL_VERY_STRONG : 
                            (confidence >= 60) ? SIGNAL_STRONG : SIGNAL_MODERATE;
            signal.entryPrice = askPrice;
            signal.stopLoss = stopLossBuy;
            signal.takeProfit = takeProfitBuy;
            signal.trendDirection = (htfBullish ? DIRECTION_UP : DIRECTION_NONE);
            signal.timestamp = TimeCurrent();
            signal.description = "[TREND/BUY] " + signalDescription;
        }
    }
    
    // SELL SIGNAL
    if(atrValid && adxConfirmed && rsiNormal)
    {
        confirmations = 0;
        signalDescription = "";
        
        if(adxConfirmed) { confirmations++; signalDescription += "ADX "; }
        if(rsiBearish && rsiNormal) { confirmations++; signalDescription += "RSI- "; }
        if(macdBearish) { confirmations++; signalDescription += "MACD- "; }
        if(stochBearish) { confirmations++; signalDescription += "Stoch- "; }
        if(volumeFilterPassed) { confirmations++; signalDescription += "Vol "; }
        if(htfBearish) { confirmations++; signalDescription += "HTF- "; }
        if(structureBearish) { confirmations++; signalDescription += "Struct "; }
        if(bearishEngulf) { confirmations++; signalDescription += "Engulf "; }
        if(bearishFVG) { confirmations++; signalDescription += "FVG "; }
        
        double confidence = (double)confirmations / 9.0 * 100;
        
        if(confirmations >= InpMinConfirmations)
        {
            signal.sellSignal = true;
            signal.buySignal = false;
            signal.confidence = confidence;
            signal.confirmations = confirmations;
            signal.quality = (confidence >= 80) ? SIGNAL_VERY_STRONG : 
                            (confidence >= 60) ? SIGNAL_STRONG : SIGNAL_MODERATE;
            signal.entryPrice = bidPrice;
            signal.stopLoss = stopLossSell;
            signal.takeProfit = takeProfitSell;
            signal.trendDirection = (htfBearish ? DIRECTION_DOWN : DIRECTION_NONE);
            signal.timestamp = TimeCurrent();
            signal.description = "[TREND/SELL] " + signalDescription;
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| DETECT MEAN REVERSION SIGNAL                                      |
//+------------------------------------------------------------------+
STradeSignal DetectMeanRevSignal()
{
    STradeSignal signal;
    ZeroMemory(signal);
    signal.mode = TRADE_MODE_MEAN_REV;
    
    if(!InpUseMeanRevEngine)
        return signal;
    
    // Get indicator values
    double bbUpper[], bbMiddle[], bbLower[];
    double atrValue;
    double rsiValue;
    double close[], high[], low[], open[];
    double volume[], volumeMA[];
    
    ArraySetAsSeries(bbUpper, true);
    ArraySetAsSeries(bbMiddle, true);
    ArraySetAsSeries(bbLower, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(volume, true);
    ArraySetAsSeries(volumeMA, true);
    
    if(CopyBuffer(g_handleBB, 0, 0, 5, bbUpper) <= 0) return signal;
    if(CopyBuffer(g_handleBB, 1, 0, 5, bbMiddle) <= 0) return signal;
    if(CopyBuffer(g_handleBB, 2, 0, 5, bbLower) <= 0) return signal;
    if(CopyBuffer(g_handleRSI, 0, 0, 5, rsiValue) <= 0) return signal;
    if(CopyBuffer(g_handleATR, 0, 0, 5, atrValue) <= 0) return signal;
    if(CopyBuffer(g_handleVolumeMA, 0, 0, 5, volumeMA) <= 0) return signal;
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, close) <= 0) return signal;
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, high) <= 0) return signal;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, low) <= 0) return signal;
    if(CopyOpen(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, open) <= 0) return signal;
    if(CopyTickVolume(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, volume) <= 0) return signal;
    
    if(!MathIsValidNumber(bbUpper[0]) || !MathIsValidNumber(rsiValue) || !MathIsValidNumber(atrValue))
        return signal;
    
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    double askPrice = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    
    // Calculate VWAP
    double vwapValue = 0;
    if(InpUseVWAP)
        vwapValue = CalculateVWAP();
    
    // Bollinger Band analysis
    double bbWidth = (bbUpper[0] - bbLower[0]) / point;
    double bbWidthPrev = (bbUpper[1] - bbLower[1]) / point;
    bool bbExpanded = (bbWidth > bbWidthPrev);
    
    // Price position
    bool priceBelowLower = (close[0] < bbLower[0]);
    bool priceAboveUpper = (close[0] > bbUpper[0]);
    bool atrValid = (atrValue >= InpMinVolatility * point) && (atrValue <= InpMaxVolatility * point);
    if(!atrValid) return signal;
    
    double atrPoints = atrValue / point;
    
    // Volume exhaustion
    bool volumeLow = (volume[0] < volumeMA[0] * 0.7);
    bool volumeExhausted = volumeLow;
    
    // RSI extremes
    bool rsiOversold = (rsiValue < InpRSIOversold);
    bool rsiOverbought = (rsiValue > InpRSIOverbought);
    
    // Pin bar detection
    double bodySize = MathAbs(close[0] - open[0]) / point;
    double upperWick = (high[0] - MathMax(open[0], close[0])) / point;
    double lowerWick = (MathMin(open[0], close[0]) - low[0]) / point;
    bool bullishPin = (lowerWick > bodySize * 2) && (upperWick < bodySize * 0.5) && (close[0] > open[0]);
    bool bearishPin = (upperWick > bodySize * 2) && (lowerWick < bodySize * 0.5) && (close[0] < open[0]);
    
    // VWAP confirmation
    bool aboveVWAP = (vwapValue > 0) && (close[0] > vwapValue);
    bool belowVWAP = (vwapValue > 0) && (close[0] < vwapValue);
    
    int confirmations = 0;
    string signalDescription = "";
    
    // BUY - At lower band expecting bounce
    if(priceBelowLower && atrValid)
    {
        confirmations = 0;
        signalDescription = "";
        
        if(rsiOversold) { confirmations++; signalDescription += "RSI_OS "; }
        if(volumeExhausted) { confirmations++; signalDescription += "VolEx "; }
        if(bullishPin) { confirmations++; signalDescription += "PinBar "; }
        if(bbExpanded) { confirmations++; signalDescription += "BBExp "; }
        if(!InpUseVWAP || aboveVWAP) { confirmations++; signalDescription += "AboveVWAP "; }
        
        double confidence = (double)confirmations / 5.0 * 100;
        
        if(confirmations >= InpMinConfirmations)
        {
            double slDist = atrPoints * InpATRSLMultiplier * 1.2;
            double tpDist = atrPoints * InpATRTPMultiplier;
            slDist = MathMax(slDist, InpMinTradeDistance);
            tpDist = MathMax(tpDist, InpMinTradeDistance * 2);
            
            signal.buySignal = true;
            signal.sellSignal = false;
            signal.confidence = confidence;
            signal.confirmations = confirmations;
            signal.quality = (confidence >= 80) ? SIGNAL_VERY_STRONG : 
                            (confidence >= 60) ? SIGNAL_STRONG : SIGNAL_MODERATE;
            signal.entryPrice = askPrice;
            signal.stopLoss = NormalizeDouble(askPrice - slDist * point, _Digits);
            signal.takeProfit = NormalizeDouble(askPrice + tpDist * point, _Digits);
            signal.trendDirection = DIRECTION_REVERSAL_UP;
            signal.timestamp = TimeCurrent();
            signal.description = "[MEAN_REV/BUY] " + signalDescription;
        }
    }
    
    // SELL - At upper band expecting drop
    if(priceAboveUpper && atrValid)
    {
        confirmations = 0;
        signalDescription = "";
        
        if(rsiOverbought) { confirmations++; signalDescription += "RSI_OB "; }
        if(volumeExhausted) { confirmations++; signalDescription += "VolEx "; }
        if(bearishPin) { confirmations++; signalDescription += "PinBar "; }
        if(bbExpanded) { confirmations++; signalDescription += "BBExp "; }
        if(!InpUseVWAP || belowVWAP) { confirmations++; signalDescription += "BelowVWAP "; }
        
        double confidence = (double)confirmations / 5.0 * 100;
        
        if(confirmations >= InpMinConfirmations)
        {
            double slDist = atrPoints * InpATRSLMultiplier * 1.2;
            double tpDist = atrPoints * InpATRTPMultiplier;
            slDist = MathMax(slDist, InpMinTradeDistance);
            tpDist = MathMax(tpDist, InpMinTradeDistance * 2);
            
            signal.sellSignal = true;
            signal.buySignal = false;
            signal.confidence = confidence;
            signal.confirmations = confirmations;
            signal.quality = (confidence >= 80) ? SIGNAL_VERY_STRONG : 
                            (confidence >= 60) ? SIGNAL_STRONG : SIGNAL_MODERATE;
            signal.entryPrice = bidPrice;
            signal.stopLoss = NormalizeDouble(bidPrice + slDist * point, _Digits);
            signal.takeProfit = NormalizeDouble(bidPrice - tpDist * point, _Digits);
            signal.trendDirection = DIRECTION_REVERSAL_DOWN;
            signal.timestamp = TimeCurrent();
            signal.description = "[MEAN_REV/SELL] " + signalDescription;
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| CALCULATE VWAP                                                   |
//+------------------------------------------------------------------+
double CalculateVWAP()
{
    double vwap = 0;
    double cumulativeTPV = 0;
    double cumulativeVolume = 0;
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime sessionStart;
    
    if(InpVWAPSession == 0)
        sessionStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    else
    {
        int dayOfWeek = dt.day_of_week;
        int daysToSubtract = (dayOfWeek - 1 < 0) ? 6 : dayOfWeek - 1;
        sessionStart = StringToTime(TimeToString(TimeCurrent() - daysToSubtract * 86400, TIME_DATE));
    }
    
    int bars = Bars(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, sessionStart, TimeCurrent());
    if(bars <= 0 || bars > 500) bars = 500;
    
    double closePrices[], highPrices[], lowPrices[], volumePrices[];
    ArraySetAsSeries(closePrices, true);
    ArraySetAsSeries(highPrices, true);
    ArraySetAsSeries(lowPrices, true);
    ArraySetAsSeries(volumePrices, true);
    
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, bars, closePrices) <= 0) return 0;
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, bars, highPrices) <= 0) return 0;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, bars, lowPrices) <= 0) return 0;
    if(CopyTickVolume(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, bars, volumePrices) <= 0) return 0;
    
    int maxBars = MathMin(bars, 500);
    for(int i = 0; i < maxBars; i++)
    {
        if(!MathIsValidNumber(closePrices[i]) || !MathIsValidNumber(highPrices[i]) || 
           !MathIsValidNumber(lowPrices[i]) || !MathIsValidNumber(volumePrices[i]))
            continue;
            
        double typicalPrice = (highPrices[i] + lowPrices[i] + closePrices[i]) / 3.0;
        cumulativeTPV += typicalPrice * volumePrices[i];
        cumulativeVolume += volumePrices[i];
    }
    
    if(cumulativeVolume > 0)
        vwap = cumulativeTPV / cumulativeVolume;
    
    return vwap;
}

//+------------------------------------------------------------------+
//| DETECT MARKET STRUCTURE                                          |
//+------------------------------------------------------------------+
void DetectMarketStructure(bool &bullish, bool &bearish)
{
    bullish = false;
    bearish = false;
    
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 20, high) <= 0) return;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 20, low) <= 0) return;
    
    // Find swing high/low
    double swingHigh = high[0], swingLow = low[0];
    int shIdx = 0, slIdx = 0;
    
    for(int i = 1; i < 20; i++)
    {
        if(high[i] > swingHigh) { swingHigh = high[i]; shIdx = i; }
        if(low[i] < swingLow) { swingLow = low[i]; slIdx = i; }
    }
    
    if(shIdx < slIdx) bullish = true;
    else bearish = true;
}

//+------------------------------------------------------------------+
//| DETECT ORDER BLOCK                                               |
//+------------------------------------------------------------------+
double DetectOrderBlock(bool isBullish)
{
    double obLevel = 0;
    
    double close[], open[], high[], low[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 10, close) <= 0) return 0;
    if(CopyOpen(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 10, open) <= 0) return 0;
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 10, high) <= 0) return 0;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 10, low) <= 0) return 0;
    
    for(int i = 2; i < 10; i++)
    {
        double prevBody = MathAbs(close[i+1] - open[i+1]);
        double prevRange = high[i+1] - low[i+1];
        bool prevBull = (close[i+1] > open[i+1]);
        
        double currBody = MathAbs(close[i] - open[i]);
        double currRange = high[i] - low[i];
        
        if(isBullish && prevBull && prevBody > prevRange * 0.7)
        {
            if(currBody < prevBody * 0.5 && currRange < prevRange * 0.5)
            {
                obLevel = low[i];
                break;
            }
        }
        else if(!isBullish && !prevBull && prevBody > prevRange * 0.7)
        {
            if(currBody < prevBody * 0.5 && currRange < prevRange * 0.5)
            {
                obLevel = high[i];
                break;
            }
        }
    }
    
    return obLevel;
}

//+------------------------------------------------------------------+
//| DETECT FAIR VALUE GAP                                            |
//+------------------------------------------------------------------+
void DetectFairValueGap(bool &bullishFVG, bool &bearishFVG, double &midLevel)
{
    bullishFVG = false;
    bearishFVG = false;
    midLevel = 0;
    
    double close[], open[], high[], low[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 3, close) <= 0) return;
    if(CopyOpen(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 3, open) <= 0) return;
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 3, high) <= 0) return;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 3, low) <= 0) return;
    
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    
    double bullishGap = low[1] - high[2];
    if(bullishGap > InpMinTradeDistance * point)
    {
        bullishFVG = true;
        midLevel = (low[1] + high[2]) / 2;
    }
    
    double bearishGap = high[1] - low[2];
    if(bearishGap > InpMinTradeDistance * point)
    {
        bearishFVG = true;
        midLevel = (high[1] + low[2]) / 2;
    }
}

//+------------------------------------------------------------------+
//| CHECK DXY FILTER                                                 |
//+------------------------------------------------------------------+
bool CheckDXYFilter()
{
    if(!InpUseDXYFilter) return true;
    
    double dxyRSI[];
    ArraySetAsSeries(dxyRSI, true);
    
    int dxyHandle = iRSI(InpDXYSymbol, PERIOD_H1, 14, PRICE_CLOSE);
    if(dxyHandle == INVALID_HANDLE) return true;
    
    if(CopyBuffer(dxyHandle, 0, 0, 2, dxyRSI) <= 0)
    {
        IndicatorRelease(dxyHandle);
        return true;
    }
    IndicatorRelease(dxyHandle);
    
    return !(dxyRSI[0] > 70 || dxyRSI[0] < 30);
}

//+------------------------------------------------------------------+
//| CHECK VIX FILTER                                                 |
//+------------------------------------------------------------------+
bool CheckVIXFilter()
{
    if(!InpUseVIXFilter) return true;
    
    double atrCurrent;
    if(CopyBuffer(g_handleATR, 0, 0, 1, atrCurrent) <= 0) return true;
    
    int atrMaHandle = iMA(InpSymbol, PERIOD_D1, 20, 0, MODE_SMA, PRICE_CLOSE);
    if(atrMaHandle == INVALID_HANDLE) return true;
    
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    if(CopyBuffer(atrMaHandle, 0, 0, 2, atrBuffer) <= 0)
    {
        IndicatorRelease(atrMaHandle);
        return true;
    }
    IndicatorRelease(atrMaHandle);
    
    return !(atrCurrent > atrBuffer[0] * 2);
}

//+------------------------------------------------------------------+
//| DAILY RESET CHECK                                                |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    datetime currentDate = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    
    if(currentDate > g_lastDailyReset)
    {
        g_lastDailyReset = currentDate;
        g_consecutiveLosses = 0;
        g_lastTradeTime = 0;
        
        if(InpDebugMode)
            Print("Daily reset performed. New trading day started.");
    }
}

//+------------------------------------------------------------------+
//| VALIDATE MARKET CONDITIONS                                       |
//+------------------------------------------------------------------+
bool ValidateMarketConditions()
{
    if(!SymbolSelect(InpSymbol, true))
    {
        if(InpDebugMode) Print("ERROR: Symbol not available");
        return false;
    }
    
    double spread = (double)SymbolInfoInteger(InpSymbol, SYMBOL_SPREAD);
    if(spread > InpMaxSpread)
    {
        if(InpDebugMode) Print("Blocked: Spread too high");
        return false;
    }
    
    MqlTick lastTick;
    if(!SymbolInfoTick(InpSymbol, lastTick))
    {
        if(InpDebugMode) Print("ERROR: Failed to get tick");
        return false;
    }
    
    if(lastTick.time < TimeCurrent() - 60)
    {
        if(InpDebugMode) Print("WARNING: Stale tick data");
        return false;
    }
    
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    if(equity < balance * (1 - InpDailyLossLimit / 100))
    {
        if(InpVerboseLogging) Print("Blocked: Daily loss limit reached");
        return false;
    }
    
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    if(marginLevel > 0 && marginLevel < 150)
    {
        if(InpDebugMode) Print("WARNING: Low margin level");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| UPDATE SESSION INFO                                              |
//+------------------------------------------------------------------+
void UpdateSessionInfo()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int currentHour = dt.hour;
    
    if(currentHour >= InpAsianStartHour && currentHour < InpAsianEndHour)
        g_currentSession = SESSION_ASIAN;
    else if(currentHour >= InpDeadZoneStartHour && currentHour < InpDeadZoneEndHour)
        g_currentSession = SESSION_DEAD_ZONE;
    else if(currentHour >= InpLondonStartHour && currentHour < InpLondonEndHour)
        g_currentSession = SESSION_LONDON;
    else if(currentHour >= InpNewYorkStartHour && currentHour < InpNewYorkEndHour)
        g_currentSession = SESSION_NEW_YORK;
    else
        g_currentSession = SESSION_DEAD_ZONE;
}

//+------------------------------------------------------------------+
//| CHECK IF IN COOLDOWN                                             |
//+------------------------------------------------------------------+
bool IsInCooldown()
{
    if(g_lastTradeTime == 0) return false;
    
    datetime cooldownEnd = g_lastTradeTime + InpCooldownMinutes * 60;
    if(TimeCurrent() < cooldownEnd)
    {
        if(InpDebugMode)
            Print("In cooldown: ", (cooldownEnd - TimeCurrent()) / 60, " min remaining");
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| CHECK TRADING LIMITS                                             |
//+------------------------------------------------------------------+
bool CheckTradingLimits()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dailyLoss = (balance > 0) ? (balance - equity) / balance * 100 : 0;
    
    if(dailyLoss >= InpDailyLossLimit)
    {
        if(InpVerboseLogging) Print("BLOCKED: Daily loss limit");
        return false;
    }
    
    if(g_consecutiveLosses >= InpMaxConsecutiveLoss)
    {
        if(InpVerboseLogging) Print("BLOCKED: Max consecutive losses");
        return false;
    }
    
    int todayTrades = CountTodayTrades();
    if(todayTrades >= InpMaxGlobalTrades)
    {
        if(InpDebugMode) Print("BLOCKED: Max daily trades");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| COUNT TODAY'S TRADES                                             |
//+------------------------------------------------------------------+
int CountTodayTrades()
{
    int count = 0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == InpSymbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            if(PositionGetInteger(POSITION_OPEN_TIME) >= todayStart)
                count++;
        }
    }
    
    HistorySelect(todayStart, TimeCurrent());
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(dealTicket > 0 && HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber)
            count++;
    }
    HistorySelect(0, TimeCurrent());
    
    return MathMax(count / 2, 0);
}

//+------------------------------------------------------------------+
//| HAS OPEN POSITION                                                 |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == InpSymbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| GET OPEN POSITION TICKET                                         |
//+------------------------------------------------------------------+
ulong GetOpenPositionTicket()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == InpSymbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            return PositionGetTicket(i);
    }
    return 0;
}

//+------------------------------------------------------------------+
//| EXECUTE TRADE                                                    |
//+------------------------------------------------------------------+
bool ExecuteTrade(STradeSignal &signal)
{
    if(!signal.buySignal && !signal.sellSignal) return false;
    
    if(!MathIsValidNumber(signal.entryPrice) || !MathIsValidNumber(signal.stopLoss) || 
       !MathIsValidNumber(signal.takeProfit))
    {
        if(InpDebugMode) Print("ERROR: Invalid signal values");
        return false;
    }
    
    // Adaptive lot sizing based on regime
    double riskPercent = InpRiskPercent;
    if(InpAdaptiveRisk)
    {
        riskPercent = CalculateAdaptiveRisk(signal);
    }
    
    double lotSize = CalculateLotSize(signal.stopLoss, signal.entryPrice, riskPercent);
    if(lotSize < SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN))
    {
        if(InpDebugMode) Print("ERROR: Lot size below minimum");
        return false;
    }
    lotSize = NormalizeLot(lotSize);
    
    double price = signal.entryPrice;
    double sl = signal.stopLoss;
    double tp = signal.takeProfit;
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    
    double minDistance = SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    if(MathAbs(price - sl) < minDistance || MathAbs(price - tp) < minDistance)
    {
        if(InpDebugMode) Print("ERROR: SL/TP too close");
        return false;
    }
    
    bool result = false;
    if(signal.buySignal)
        result = g_trade.Buy(lotSize, InpSymbol, price, sl, tp, signal.description);
    else
        result = g_trade.Sell(lotSize, InpSymbol, price, sl, tp, signal.description);
    
    if(result)
    {
        ulong ticket = g_trade.ResultOrder();
        if(InpVerboseLogging)
        {
            Print("===========================================");
            Print("TRADE OPENED: ", signal.buySignal ? "BUY" : "SELL");
            Print("Ticket: ", ticket, " Symbol: ", InpSymbol);
            Print("Lot: ", DoubleToString(lotSize, 2));
            Print("Entry: ", DoubleToString(price, _Digits));
            Print("SL: ", DoubleToString(sl, _Digits), " TP: ", DoubleToString(tp, _Digits));
            Print("Confidence: ", DoubleToString(signal.confidence, 1), "%");
            Print("Neural Score: ", DoubleToString(signal.neuralScore * 100, 1), "%");
            Print("Regime: ", EnumToString(signal.detectedRegime));
            Print("===========================================");
        }
        g_lastTradeTime = TimeCurrent();
    }
    else
    {
        if(InpDebugMode)
        {
            Print("ERROR: Trade failed - Code: ", g_trade.ResultRetcode());
        }
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| CALCULATE ADAPTIVE RISK                                           |
//+------------------------------------------------------------------+
double CalculateAdaptiveRisk(STradeSignal &signal)
{
    double baseRisk = InpRiskPercent;
    
    // Adjust based on regime strength
    if(g_regimeStrength > 0.7)
        baseRisk *= 1.2; // Increase risk in strong regimes
    else if(g_regimeStrength < 0.3)
        baseRisk *= 0.7; // Decrease risk in weak regimes
    
    // Adjust based on win rate
    if(g_winRate > 0.6)
        baseRisk *= 1.1;
    else if(g_winRate < 0.4)
        baseRisk *= 0.8;
    
    // Adjust based on neural confidence
    if(signal.neuralScore > 0.8)
        baseRisk *= 1.15;
    else if(signal.neuralScore < 0.4)
        baseRisk *= 0.75;
    
    // Apply base multiplier
    baseRisk *= InpBaseRiskMultiplier;
    
    // Clamp to reasonable range
    return MathMax(MathMin(baseRisk, 3.0), 0.1);
}

//+------------------------------------------------------------------+
//| CALCULATE LOT SIZE                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLoss, double entryPrice, double riskPercent)
{
    double lotSize;
    
    if(InpFixedLot > 0)
    {
        lotSize = InpFixedLot;
    }
    else
    {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * (riskPercent / 100.0);
        
        double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
        double stopLossDistance = MathAbs(entryPrice - stopLoss) / point;
        
        double tickValue = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
        
        double riskPerPoint = (stopLossDistance * tickValue) / tickSize;
        
        if(riskPerPoint > 0)
            lotSize = riskAmount / riskPerPoint;
        else
            lotSize = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
        
        double minLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
        lotSize = MathMax(lotSize, minLot);
        lotSize = MathMin(lotSize, maxLot);
    }
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| NORMALIZE LOT TO BROKER REQUIREMENTS                             |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
    double minLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);
    
    if(lotStep > 0)
        lot = MathRound(lot / lotStep) * lotStep;
    
    lot = MathMax(lot, minLot);
    lot = MathMin(lot, maxLot);
    
    return lot;
}

//+------------------------------------------------------------------+
//| MANAGE OPEN TRADE                                                |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
    ulong ticket = GetOpenPositionTicket();
    if(ticket == 0) return;
    
    if(!PositionSelectByTicket(ticket)) return;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double positionSL = PositionGetDouble(POSITION_SL);
    double positionTP = PositionGetDouble(POSITION_TP);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    
    double atrValue;
    if(CopyBuffer(g_handleATR, 0, 0, 1, atrValue) <= 0) return;
    double atrPoints = atrValue / point;
    
    // Break-even logic
    if(InpBreakEvenTrigger > 0 && positionSL != 0)
    {
        double beLevel = (posType == POSITION_TYPE_BUY) ? 
                        openPrice + atrPoints * InpBreakEvenTrigger * point :
                        openPrice - atrPoints * InpBreakEvenTrigger * point;
        
        bool shouldBE = (posType == POSITION_TYPE_BUY && currentPrice >= beLevel && positionSL < openPrice) ||
                      (posType == POSITION_TYPE_SELL && currentPrice <= beLevel && positionSL > openPrice);
        
        if(shouldBE)
        {
            double newSL = (posType == POSITION_TYPE_BUY) ?
                          NormalizeDouble(openPrice + InpBreakEvenBuffer * atrPoints * point, _Digits) :
                          NormalizeDouble(openPrice - InpBreakEvenBuffer * atrPoints * point, _Digits);
            
            bool updateSL = (posType == POSITION_TYPE_BUY && newSL > positionSL) ||
                           (posType == POSITION_TYPE_SELL && newSL < positionSL);
            
            if(updateSL)
            {
                g_trade.PositionModify(ticket, newSL, positionTP);
                if(InpDebugMode) Print("Break-even set: ", DoubleToString(newSL, _Digits));
            }
        }
    }
    
    // Partial close at TP1
    if(InpUsePartialClose)
    {
        double tp1Level = (posType == POSITION_TYPE_BUY) ?
                         openPrice + atrPoints * InpATRTPMultiplier * InpTP1Percent / 100.0 * point :
                         openPrice - atrPoints * InpATRTPMultiplier * InpTP1Percent / 100.0 * point;
        
        bool reachedTP1 = (posType == POSITION_TYPE_BUY && currentPrice >= tp1Level) ||
                         (posType == POSITION_TYPE_SELL && currentPrice <= tp1Level);
        
        if(reachedTP1)
        {
            double closeVol = NormalizeLot(volume * InpPartialClosePercent / 100.0);
            double minVol = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
            
            if(closeVol >= minVol)
            {
                if(g_trade.PositionClosePartial(ticket, closeVol))
                {
                    if(InpVerboseLogging) Print("Partial close at TP1");
                }
            }
        }
    }
    
    // Trailing stop
    if(InpUseTrailingStop)
    {
        double trailStart = (posType == POSITION_TYPE_BUY) ?
                          openPrice + atrPoints * InpATRTPMultiplier * InpTrailStartPercent / 100.0 * point :
                          openPrice - atrPoints * InpATRTPMultiplier * InpTrailStartPercent / 100.0 * point;
        
        if((posType == POSITION_TYPE_BUY && currentPrice >= trailStart) ||
           (posType == POSITION_TYPE_SELL && currentPrice <= trailStart))
        {
            double newTrailSL = (posType == POSITION_TYPE_BUY) ?
                               NormalizeDouble(currentPrice - atrPoints * InpATRSLMultiplier * InpTrailDistancePercent / 100.0 * point, _Digits) :
                               NormalizeDouble(currentPrice + atrPoints * InpATRSLMultiplier * InpTrailDistancePercent / 100.0 * point, _Digits);
            
            bool updateTrail = (posType == POSITION_TYPE_BUY && newTrailSL > positionSL) ||
                             (posType == POSITION_TYPE_SELL && (newTrailSL < positionSL || positionSL == 0));
            
            if(updateTrail)
            {
                g_trade.PositionModify(ticket, newTrailSL, positionTP);
                if(InpDebugMode) Print("Trailing SL: ", DoubleToString(newTrailSL, _Digits));
            }
        }
    }
    
    // Smart exit on reversal
    if(InpUseSmartExit)
    {
        CheckSmartExit(ticket, posType, currentPrice, openPrice);
    }
}

//+------------------------------------------------------------------+
//| SMART EXIT ON REVERSAL                                           |
//+------------------------------------------------------------------+
void CheckSmartExit(ulong ticket, ENUM_POSITION_TYPE posType, double currentPrice, double openPrice)
{
    // Get RSI for reversal detection
    double rsiValue;
    if(CopyBuffer(g_handleRSI, 0, 0, 3, rsiValue) <= 0) return;
    
    // Get ADX for trend strength
    double adxValue;
    if(CopyBuffer(g_handleADX, 0, 0, 3, adxValue) <= 0) return;
    
    // Detect reversal
    bool reversalSignal = false;
    if(posType == POSITION_TYPE_BUY && rsiValue < 40 && adxValue < 20)
        reversalSignal = true;
    else if(posType == POSITION_TYPE_SELL && rsiValue > 60 && adxValue < 20)
        reversalSignal = true;
    
    // Calculate current profit
    double profit = (posType == POSITION_TYPE_BUY) ?
                   (currentPrice - openPrice) * 10 : // Simplified
                   (openPrice - currentPrice) * 10;
    
    // Exit with small profit if reversal detected
    if(reversalSignal && profit > 0)
    {
        // Close 50% of position
        double volume = PositionGetDouble(POSITION_VOLUME);
        double closeVol = NormalizeLot(volume * 0.5);
        
        if(closeVol >= SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN))
        {
            if(g_trade.PositionClosePartial(ticket, closeVol))
            {
                if(InpVerboseLogging) Print("Smart exit: Closed 50% on reversal");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| TRADE TRANSACTION HANDLER                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        ulong dealTicket = trans.deal;
        if(dealTicket > 0)
        {
            if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber)
            {
                double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                
                // Update learning data
                g_recentPerformance[g_performanceIndex] = dealProfit;
                g_performanceIndex = (g_performanceIndex + 1) % InpLearningPeriod;
                
                // Update consecutive losses
                if(dealProfit < 0)
                {
                    g_consecutiveLosses++;
                }
                else
                {
                    g_consecutiveLosses = 0;
                }
                
                if(InpVerboseLogging)
                {
                    Print("Deal closed: ", dealTicket, " Profit: ", DoubleToString(dealProfit, 2));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| CHART EVENT                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    if(id == CHARTEVENT_KEYDOWN)
    {
        if(lparam == 123) // F12
        {
            CloseAllTrades();
        }
    }
}

//+------------------------------------------------------------------+
//| CLOSE ALL TRADES                                                 |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionGetString(POSITION_SYMBOL) == InpSymbol && 
           PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            g_trade.PositionClose(ticket);
            if(InpDebugMode) Print("Emergency close: ", ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| PRINT STATISTICS                                                  |
//+------------------------------------------------------------------+
void PrintStatistics()
{
    double totalProfit = 0;
    int totalTrades = 0, winningTrades = 0, losingTrades = 0;
    
    datetime startDate = StringToTime("2020.01.01");
    HistorySelect(startDate, TimeCurrent());
    
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
        {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            totalProfit += profit;
            totalTrades++;
            if(profit > 0) winningTrades++;
            else if(profit < 0) losingTrades++;
        }
    }
    HistorySelect(0, TimeCurrent());
    
    if(totalTrades > 0)
    {
        double winRate = (double)winningTrades / totalTrades * 100;
        Print("===========================================");
        Print("STATISTICS - Neural Adaptive EA v3.0");
        Print("Total Trades: ", totalTrades);
        Print("Wins: ", winningTrades, " Losses: ", losingTrades);
        Print("Win Rate: ", DoubleToString(winRate, 2), "%");
        Print("Total P&L: ", DoubleToString(totalProfit, 2));
        Print("Regime: ", EnumToString(g_currentRegime));
        Print("===========================================");
    }
}

//+------------------------------------------------------------------+
//| END OF EXPERT ADVISOR                                            |
//+------------------------------------------------------------------+

