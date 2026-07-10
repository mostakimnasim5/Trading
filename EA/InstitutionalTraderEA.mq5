//+------------------------------------------------------------------+
//|                                    InstitutionalTraderEA.mq5     |
//|                                      Professional Trading System |
//|                                          20 Years Experience     |
//+------------------------------------------------------------------+
#property copyright "Professional Trading System"
#property version   "2.0"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_TRADE_MODE
{
    TRADE_MODE_TREND     = 0,  // Trend/SMC during kill zones
    TRADE_MODE_MEAN_REV  = 1,  // Mean reversion off-sessions
    TRADE_MODE_BOTH      = 2   // Both modes active
};

enum ENUM_SIGNAL_QUALITY
{
    SIGNAL_WEAK         = 0,
    SIGNAL_MODERATE     = 1,
    SIGNAL_STRONG       = 2,
    SIGNAL_VERY_STRONG  = 3
};

enum ENUM_SESSION
{
    SESSION_ASIAN       = 0,
    SESSION_LONDON      = 1,
    SESSION_NEW_YORK    = 2,
    SESSION_DEAD_ZONE   = 3
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - SYMBOL & BASIC                               |
//+------------------------------------------------------------------+
input group "===== SYMBOL & BASIC ====="
input string   InpSymbol = "EURUSD";              // Trading Symbol
input ENUM_TRADE_MODE InpTradeMode = TRADE_MODE_BOTH; // Trading Mode
input ulong    InpMagicNumber = 2025001;           // Magic Number

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - RISK MANAGEMENT                               |
//+------------------------------------------------------------------+
input group "===== RISK MANAGEMENT ====="
input double   InpRiskPercent = 1.0;              // Risk Per Trade (%)
input double   InpFixedLot = 0.0;                 // Fixed Lot (0 = use risk %)
input double   InpMaxSpread = 25;                 // Maximum Spread (points)
input int      InpMaxSlippage = 30;               // Maximum Slippage (points)
input double   InpDailyLossLimit = 5.0;           // Daily Loss Limit (%)
input int      InpMaxConsecutiveLoss = 5;          // Max Consecutive Losses
input int      InpMaxGlobalTrades = 3;             // Max Global Trades Per Day
input int      InpCooldownMinutes = 15;            // Cooldown After Trade (min)
input double   InpMinTradeDistance = 50;           // Min Distance from Price (points)

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - SESSION TIMES                                 |
//+------------------------------------------------------------------+
input group "===== SESSION TIMES ====="
input int      InpAsianStartHour = 0;              // Asian Session Start Hour (GMT)
input int      InpAsianEndHour = 9;               // Asian Session End Hour (GMT)
input int      InpLondonStartHour = 7;             // London Session Start Hour (GMT)
input int      InpLondonEndHour = 11;              // London Session End Hour (GMT)
input int      InpNewYorkStartHour = 12;           // New York Session Start Hour (GMT)
input int      InpNewYorkEndHour = 16;             // New York Session End Hour (GMT)
input int      InpDeadZoneStartHour = 16;          // Dead Zone Start Hour (GMT)
input int      InpDeadZoneEndHour = 21;            // Dead Zone End Hour (GMT)

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - TREND ENGINE SETTINGS                        |
//+------------------------------------------------------------------+
input group "===== TREND ENGINE (SMC) ====="
input bool     InpUseTrendEngine = true;           // Enable Trend Engine
input int      InpTrendTimeframe = 5;              // Trend Timeframe (minutes)
input int      InpHTFConfirm = 60;                 // Higher TF Confirmation (minutes)
input int      InpADXPeriod = 14;                  // ADX Period
input double   InpADXMinStrength = 25;             // ADX Minimum Strength
input int      InpRSIPeriod = 14;                  // RSI Period
input double   InpRSIOverbought = 70;              // RSI Overbought Level
input double   InpRSIOversold = 30;               // RSI Oversold Level
input int      InpMACDFast = 12;                  // MACD Fast EMA
input int      InpMACDSlow = 26;                  // MACD Slow EMA
input int      InpMACDSignal = 9;                  // MACD Signal

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - ATR & VOLATILITY                              |
//+------------------------------------------------------------------+
input group "===== ATR & VOLATILITY ====="
input int      InpATRPeriod = 14;                  // ATR Period
input double   InpATRSLMultiplier = 1.5;           // ATR SL Multiplier
input double   InpATRTPMultiplier = 2.5;           // ATR TP Multiplier
input double   InpMinVolatility = 10;              // Min ATR Value for Trade
input double   InpMaxVolatility = 500;             // Max ATR Value for Trade

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - VOLUME SETTINGS                               |
//+------------------------------------------------------------------+
input group "===== VOLUME SETTINGS ====="
input int      InpVolumePeriod = 20;               // Volume MA Period
input double   InpVolumeSpikeMultiplier = 2.0;     // Volume Spike Threshold
input bool     InpUseVolumeFilter = true;          // Use Volume Filter

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - BOLLINGER BAND (MEAN REV)                     |
//+------------------------------------------------------------------+
input group "===== BOLLINGER BAND (MEAN REVERSION) ====="
input bool     InpUseMeanRevEngine = true;         // Enable Mean Reversion Engine
input int      InpBBPeriod = 20;                  // Bollinger Period
input double   InpBBDeviation = 2.0;              // Bollinger Deviation
input int      InpBBTimeframe = 5;                // BB Timeframe

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - VWAP                                          |
//+------------------------------------------------------------------+
input group "===== VWAP SETTINGS ====="
input bool     InpUseVWAP = true;                 // Use VWAP
input int      InpVWAPSession = 1;                // VWAP Session (0=Day, 1=Week)

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - CONFIRMATION & FILTERS                        |
//+------------------------------------------------------------------+
input group "===== CONFIRMATION SETTINGS ====="
input int      InpMinConfirmations = 3;            // Minimum Required Confirmations
input double   InpConfidenceThreshold = 60;         // Minimum Confidence Score (%)
input bool     InpUseDXYFilter = false;            // Use DXY Correlation Filter
input string   InpDXYSymbol = "DXY";              // DXY Symbol
input bool     InpUseVIXFilter = false;            // Use VIX Filter
input bool     InpUseTrendFilter = true;          // Use Trend Filter

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - EXIT MANAGEMENT                               |
//+------------------------------------------------------------------+
input group "===== EXIT MANAGEMENT ====="
input double   InpBreakEvenTrigger = 1.0;          // Break-Even Trigger (ATR multiples)
input double   InpBreakEvenBuffer = 0.5;           // Break-Even Buffer (ATR)
input bool     InpUsePartialClose = true;          // Use Partial Close
input double   InpPartialClosePercent = 50;       // Partial Close Percentage
input double   InpTP1Percent = 50;               // TP1 Distance (%)
input bool     InpUseTrailingStop = true;          // Use Trailing Stop
input double   InpTrailStartPercent = 50;          // Trail Start After TP%
input double   InpTrailDistancePercent = 30;       // Trail Distance %

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - DEBUG & LOGGING                               |
//+------------------------------------------------------------------+
input group "===== DEBUG & LOGGING ====="
input bool     InpDebugMode = false;               // Enable Debug Mode
input bool     InpVerboseLogging = true;           // Verbose Trade Logging

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade          g_trade;                          // Trading class
datetime        g_lastTradeTime = 0;               // Last trade timestamp
datetime        g_lastCandleTime = 0;              // Last processed candle
double          g_dailyProfit = 0;                 // Daily profit tracking
int             g_consecutiveLosses = 0;           // Consecutive losses counter
datetime        g_lastDailyReset = 0;              // Last daily reset time
ENUM_SESSION    g_currentSession = SESSION_ASIAN;  // Current trading session

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
    string             description;
    datetime           timestamp;
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

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Reset daily tracking
    g_lastDailyReset = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    g_dailyProfit = 0;
    g_consecutiveLosses = 0;
    
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
    
    Print("===========================================");
    Print("InstitutionalTraderEA Initialized Successfully");
    Print("Symbol: ", InpSymbol);
    Print("Trade Mode: ", EnumToString(InpTradeMode));
    Print("Risk Per Trade: ", DoubleToString(InpRiskPercent, 2), "%");
    Print("===========================================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    ReleaseIndicators();
    
    // Log deinitialization reason
    string reasonText = "";
    switch(reason)
    {
        case REASON_PROGRAM:     reasonText = "Program terminated"; break;
        case REASON_REMOVE:      reasonText = "EA removed from chart"; break;
        case REASON_RECOMPILE:   reasonText = "EA recompiled"; break;
        case REASON_CHARTCHANGE: reasonText = "Symbol or timeframe changed"; break;
        case REASON_CHARTCLOSE: reasonText = "Chart closed"; break;
        case REASON_PARAMETERS:  reasonText = "Input parameters changed"; break;
        case REASON_ACCOUNT:     reasonText = "Account changed"; break;
        default:                 reasonText = "Unknown reason"; break;
    }
    
    if(InpDebugMode)
        Print("EA Deinitialized: ", reasonText);
}

//+------------------------------------------------------------------+
//| INDICATOR INITIALIZATION                                         |
//+------------------------------------------------------------------+
bool InitIndicators()
{
    // ADX Indicator
    g_handleADX = iADX(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpADXPeriod);
    if(g_handleADX == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create ADX indicator handle");
        return false;
    }
    
    // RSI Indicator
    g_handleRSI = iRSI(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpRSIPeriod, PRICE_CLOSE);
    if(g_handleRSI == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create RSI indicator handle");
        return false;
    }
    
    // MACD Indicator
    g_handleMACD = iMACD(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
    if(g_handleMACD == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create MACD indicator handle");
        return false;
    }
    
    // ATR Indicator
    g_handleATR = iATR(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpATRPeriod);
    if(g_handleATR == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create ATR indicator handle");
        return false;
    }
    
    // Bollinger Bands
    g_handleBB = iBands(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    if(g_handleBB == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create Bollinger Bands handle");
        return false;
    }
    
    // Volume Moving Average
    g_handleVolumeMA = iMA(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, InpVolumePeriod, 0, MODE_SMA, VOLUME_TICK);
    if(g_handleVolumeMA == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create Volume MA handle");
        return false;
    }
    
    // Simple Moving Average for trend
    g_handleMA = iMA(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(g_handleMA == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create MA handle");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| RELEASE INDICATOR HANDLES                                        |
//+------------------------------------------------------------------+
void ReleaseIndicators()
{
    if(g_handleADX != INVALID_HANDLE)
        IndicatorRelease(g_handleADX);
    if(g_handleRSI != INVALID_HANDLE)
        IndicatorRelease(g_handleRSI);
    if(g_handleMACD != INVALID_HANDLE)
        IndicatorRelease(g_handleMACD);
    if(g_handleATR != INVALID_HANDLE)
        IndicatorRelease(g_handleATR);
    if(g_handleBB != INVALID_HANDLE)
        IndicatorRelease(g_handleBB);
    if(g_handleVolumeMA != INVALID_HANDLE)
        IndicatorRelease(g_handleVolumeMA);
    if(g_handleMA != INVALID_HANDLE)
        IndicatorRelease(g_handleMA);
}

//+------------------------------------------------------------------+
//| MAIN TICK FUNCTION                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new candle (avoid processing same candle multiple times)
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
    
    // Check for existing positions
    if(HasOpenPosition())
    {
        // Manage existing trade
        ManageOpenTrade();
        return;
    }
    
    // Check cooldown
    if(IsInCooldown())
        return;
    
    // Check daily/global limits
    if(!CheckTradingLimits())
        return;
    
    // Generate trading signal based on current mode
    STradeSignal signal;
    ZeroMemory(signal);
    
    if(InpTradeMode == TRADE_MODE_TREND || InpTradeMode == TRADE_MODE_BOTH)
    {
        if(g_currentSession == SESSION_LONDON || g_currentSession == SESSION_NEW_YORK)
        {
            signal = DetectTrendSignal();
        }
    }
    
    if(InpTradeMode == TRADE_MODE_MEAN_REV || InpTradeMode == TRADE_MODE_BOTH)
    {
        if(g_currentSession == SESSION_ASIAN || g_currentSession == SESSION_DEAD_ZONE)
        {
            STradeSignal meanRevSignal = DetectMeanRevSignal();
            if(meanRevSignal.confidence > signal.confidence)
                signal = meanRevSignal;
        }
    }
    
    // Execute trade if signal is strong enough
    if(signal.confidence >= InpConfidenceThreshold && signal.confirmations >= InpMinConfirmations)
    {
        ExecuteTrade(signal);
    }
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
        g_dailyProfit = 0;
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
    // Check if symbol is selected
    if(!SymbolSelect(InpSymbol, true))
    {
        if(InpDebugMode)
            Print("ERROR: Symbol ", InpSymbol, " not available");
        return false;
    }
    
    // Check spread
    double spread = (double)SymbolInfoInteger(InpSymbol, SYMBOL_SPREAD);
    if(spread > InpMaxSpread)
    {
        if(InpDebugMode)
            Print("Blocked: Spread too high - ", spread, " > ", InpMaxSpread);
        return false;
    }
    
    // Check for proper tick data
    MqlTick lastTick;
    if(!SymbolInfoTick(InpSymbol, lastTick))
    {
        if(InpDebugMode)
            Print("ERROR: Failed to get last tick");
        return false;
    }
    
    // Check if tick is stale (older than 1 minute)
    if(lastTick.time < TimeCurrent() - 60)
    {
        if(InpDebugMode)
            Print("WARNING: Stale tick data detected");
        return false;
    }
    
    // Check account margin
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    if(equity < balance * (1 - InpDailyLossLimit / 100))
    {
        if(InpVerboseLogging)
            Print("Blocked: Daily loss limit reached. Equity: ", DoubleToString(equity, 2));
        return false;
    }
    
    // Check margin level
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    if(marginLevel > 0 && marginLevel < 150)
    {
        if(InpDebugMode)
            Print("WARNING: Low margin level - ", marginLevel);
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
    
    // Determine current session
    if(currentHour >= InpAsianStartHour && currentHour < InpAsianEndHour)
    {
        g_currentSession = SESSION_ASIAN;
    }
    else if(currentHour >= InpDeadZoneStartHour && currentHour < InpDeadZoneEndHour)
    {
        g_currentSession = SESSION_DEAD_ZONE;
    }
    else if(currentHour >= InpLondonStartHour && currentHour < InpLondonEndHour)
    {
        g_currentSession = SESSION_LONDON;
    }
    else if(currentHour >= InpNewYorkStartHour && currentHour < InpNewYorkEndHour)
    {
        g_currentSession = SESSION_NEW_YORK;
    }
    else
    {
        g_currentSession = SESSION_DEAD_ZONE;
    }
}

//+------------------------------------------------------------------+
//| CHECK IF IN COOLDOWN                                             |
//+------------------------------------------------------------------+
bool IsInCooldown()
{
    if(g_lastTradeTime == 0)
        return false;
    
    datetime cooldownEnd = g_lastTradeTime + InpCooldownMinutes * 60;
    if(TimeCurrent() < cooldownEnd)
    {
        if(InpDebugMode)
            Print("In cooldown. Time remaining: ", (cooldownEnd - TimeCurrent()) / 60, " minutes");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| CHECK TRADING LIMITS                                             |
//+------------------------------------------------------------------+
bool CheckTradingLimits()
{
    // Check daily loss limit
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dailyLoss = 0;
    
    if(balance > 0)
        dailyLoss = (balance - equity) / balance * 100;
    
    if(dailyLoss >= InpDailyLossLimit)
    {
        if(InpVerboseLogging)
            Print("BLOCKED: Daily loss limit reached - ", DoubleToString(dailyLoss, 2), "%");
        return false;
    }
    
    // Check consecutive losses
    if(g_consecutiveLosses >= InpMaxConsecutiveLoss)
    {
        if(InpVerboseLogging)
            Print("BLOCKED: Max consecutive losses reached - ", g_consecutiveLosses);
        return false;
    }
    
    // Check global trade count for the day
    int todayTrades = CountTodayTrades();
    if(todayTrades >= InpMaxGlobalTrades)
    {
        if(InpDebugMode)
            Print("BLOCKED: Max daily trades reached - ", todayTrades);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| COUNT TODAY'S TRADES                                              |
//+------------------------------------------------------------------+
int CountTodayTrades()
{
    int count = 0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    
    // Count open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == InpSymbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            if(PositionGetInteger(POSITION_OPEN_TIME) >= todayStart)
                count++;
        }
    }
    
    // Count closed trades from history
    HistorySelect(todayStart, TimeCurrent());
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(dealTicket > 0)
        {
            if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber)
                count++;
        }
    }
    HistorySelect(0, TimeCurrent());
    
    // Each trade has 2 deals (open and close), so divide by 2
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
        {
            return true;
        }
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
        {
            return PositionGetTicket(i);
        }
    }
    return 0;
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
    double adxValue, adxPlus[], adxMinus[];
    double rsiValue;
    double macdMain[], macdSignal[];
    double atrValue;
    double ma50[];
    double volume[], volumeMA[];
    double close[], high[], low[], open[];
    
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(adxPlus, true);
    ArraySetAsSeries(adxMinus, true);
    ArraySetAsSeries(macdMain, true);
    ArraySetAsSeries(macdSignal, true);
    ArraySetAsSeries(ma50, true);
    ArraySetAsSeries(volume, true);
    ArraySetAsSeries(volumeMA, true);
    
    // Copy indicator data
    if(CopyBuffer(g_handleADX, 0, 0, 5, adxValue) <= 0) return signal;
    if(CopyBuffer(g_handleADX, 1, 0, 5, adxPlus) <= 0) return signal;
    if(CopyBuffer(g_handleADX, 2, 0, 5, adxMinus) <= 0) return signal;
    if(CopyBuffer(g_handleRSI, 0, 0, 5, rsiValue) <= 0) return signal;
    if(CopyBuffer(g_handleMACD, 0, 0, 5, macdMain) <= 0) return signal;
    if(CopyBuffer(g_handleMACD, 1, 0, 5, macdSignal) <= 0) return signal;
    if(CopyBuffer(g_handleATR, 0, 0, 5, atrValue) <= 0) return signal;
    if(CopyBuffer(g_handleVolumeMA, 0, 0, 5, volumeMA) <= 0) return signal;
    if(CopyBuffer(g_handleMA, 0, 0, 5, ma50) <= 0) return signal;
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, close) <= 0) return signal;
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, high) <= 0) return signal;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, low) <= 0) return signal;
    if(CopyOpen(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, open) <= 0) return signal;
    if(CopyTickVolume(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, 5, volume) <= 0) return signal;
    
    // Check for NaN
    if(!MathIsValidNumber(adxValue) || !MathIsValidNumber(rsiValue) ||
       !MathIsValidNumber(macdMain[0]) || !MathIsValidNumber(atrValue) ||
       !MathIsValidNumber(ma50[0]))
    {
        if(InpDebugMode)
            Print("DetectTrendSignal: Invalid indicator data (NaN)");
        return signal;
    }
    
    // Get higher timeframe data for confirmation
    double h4MA;
    int htfHandle = iMA(InpSymbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(htfHandle != INVALID_HANDLE)
    {
        double h4MABuffer[];
        ArraySetAsSeries(h4MABuffer, true);
        if(CopyBuffer(htfHandle, 0, 0, 2, h4MABuffer) <= 0)
        {
            IndicatorRelease(htfHandle);
            return signal;
        }
        h4MA = h4MABuffer[0];
        IndicatorRelease(htfHandle);
    }
    
    double h4Close[];
    ArraySetAsSeries(h4Close, true);
    if(CopyClose(InpSymbol, PERIOD_H4, 0, 2, h4Close) <= 0)
        return signal;
    
    // Calculate point
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    
    // Calculate volume spike
    double volumeSpikeThreshold = volumeMA[0] * InpVolumeSpikeMultiplier;
    bool volumeConfirmed = (volume[0] >= volumeSpikeThreshold) || (volume[1] >= volumeSpikeThreshold);
    
    // Calculate ATR validity
    bool atrValid = (atrValue >= InpMinVolatility * point) && (atrValue <= InpMaxVolatility * point);
    if(!atrValid)
    {
        if(InpDebugMode)
            Print("DetectTrendSignal: ATR not in valid range");
        return signal;
    }
    
    // Calculate trend direction
    bool uptrend = (close[0] > ma50[0]);
    bool downtrend = (close[0] < ma50[0]);
    bool strongTrend = (adxValue >= InpADXMinStrength);
    
    // ADX Trend Strength Confirmation
    bool adxConfirmed = strongTrend;
    
    // RSI Confirmation
    bool rsiBuyConfirmed = (rsiValue > InpRSIOversold && rsiValue < InpRSIOverbought);
    bool rsiSellConfirmed = (rsiValue > InpRSIOversold && rsiValue < InpRSIOverbought);
    
    // MACD Confirmation (Histogram)
    double macdHistValue = macdMain[0] - macdSignal[0];
    double macdHistPrev = macdMain[1] - macdSignal[1];
    bool macdBullish = (macdHistValue > 0) || (macdHistValue > macdHistPrev);
    bool macdBearish = (macdHistValue < 0) || (macdHistValue < macdHistPrev);
    
    // Volume Confirmation
    bool volumeFilterPassed = !InpUseVolumeFilter || volumeConfirmed;
    
    // Trend Filter (HTF)
    bool htfUpTrend = (h4Close[0] > h4MA);
    bool htfDownTrend = (h4Close[0] < h4MA);
    bool trendFilterPassed = !InpUseTrendFilter || (htfUpTrend || htfDownTrend);
    
    // DXY Filter
    bool dxyFilterPassed = !InpUseDXYFilter || CheckDXYFilter();
    
    // VIX Filter
    bool vixFilterPassed = !InpUseVIXFilter || CheckVIXFilter();
    
    // Calculate entry price and SL/TP
    double askPrice = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    
    double atrPoints = atrValue / point;
    double slDistance = atrPoints * InpATRSLMultiplier;
    double tpDistance = atrPoints * InpATRTPMultiplier;
    
    // Prevent negative values
    slDistance = MathMax(slDistance, InpMinTradeDistance);
    tpDistance = MathMax(tpDistance, InpMinTradeDistance * 2);
    
    // Validate SL/TP distances
    double minSLTP = SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    if(slDistance * point < minSLTP || tpDistance * point < minSLTP)
    {
        if(InpDebugMode)
            Print("Blocked: SL/TP too close to price");
        return signal;
    }
    
    // Calculate stop loss and take profit
    double stopLossBuy = NormalizeDouble(askPrice - slDistance * point, _Digits);
    double takeProfitBuy = NormalizeDouble(askPrice + tpDistance * point, _Digits);
    double stopLossSell = NormalizeDouble(bidPrice + slDistance * point, _Digits);
    double takeProfitSell = NormalizeDouble(bidPrice - tpDistance * point, _Digits);
    
    // Price action analysis for signal quality
    double bodySize = MathAbs(close[0] - open[0]) / point;
    bool bullishCandle = (close[0] > open[0]);
    bool bearishCandle = (close[0] < open[0]);
    
    // Detect engulfing pattern
    bool bullishEngulfing = bullishCandle && (close[1] < open[1]) && 
                            (close[0] > open[1]) && (open[0] < close[1]);
    bool bearishEngulfing = bearishCandle && (close[1] > open[1]) && 
                            (close[0] < open[1]) && (open[0] > close[1]);
    
    // Count confirmations and build signals
    int confirmations = 0;
    string signalDescription = "";
    
    // BUILD BUY SIGNAL
    if(atrValid && adxConfirmed && rsiBuyConfirmed && dxyFilterPassed && vixFilterPassed)
    {
        confirmations = 0;
        signalDescription = "";
        
        if(adxConfirmed) { confirmations++; signalDescription += "ADX Strong "; }
        if(rsiBuyConfirmed) { confirmations++; signalDescription += "RSI Normal "; }
        if(macdBullish) { confirmations++; signalDescription += "MACD Bull "; }
        if(volumeFilterPassed) { confirmations++; signalDescription += "Volume Spike "; }
        if(htfUpTrend) { confirmations++; signalDescription += "HTF Up "; }
        if(bullishEngulfing) { confirmations++; signalDescription += "Bull Engulf "; }
        
        double confidence = (double)confirmations / 6.0 * 100;
        
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
            signal.timestamp = TimeCurrent();
            signal.description = "[TREND/BUY] " + signalDescription;
        }
    }
    
    // BUILD SELL SIGNAL
    if(atrValid && adxConfirmed && rsiSellConfirmed && dxyFilterPassed && vixFilterPassed)
    {
        confirmations = 0;
        signalDescription = "";
        
        if(adxConfirmed) { confirmations++; signalDescription += "ADX Strong "; }
        if(rsiSellConfirmed) { confirmations++; signalDescription += "RSI Normal "; }
        if(macdBearish) { confirmations++; signalDescription += "MACD Bear "; }
        if(volumeFilterPassed) { confirmations++; signalDescription += "Volume Spike "; }
        if(htfDownTrend) { confirmations++; signalDescription += "HTF Down "; }
        if(bearishEngulfing) { confirmations++; signalDescription += "Bear Engulf "; }
        
        double confidence = (double)confirmations / 6.0 * 100;
        
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
    
    // Copy Bollinger Bands data
    if(CopyBuffer(g_handleBB, 0, 0, 5, bbUpper) <= 0) return signal;
    if(CopyBuffer(g_handleBB, 1, 0, 5, bbMiddle) <= 0) return signal;
    if(CopyBuffer(g_handleBB, 2, 0, 5, bbLower) <= 0) return signal;
    
    // Copy other indicators
    if(CopyBuffer(g_handleRSI, 0, 0, 5, rsiValue) <= 0) return signal;
    if(CopyBuffer(g_handleATR, 0, 0, 5, atrValue) <= 0) return signal;
    if(CopyBuffer(g_handleVolumeMA, 0, 0, 5, volumeMA) <= 0) return signal;
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, close) <= 0) return signal;
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, high) <= 0) return signal;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, low) <= 0) return signal;
    if(CopyOpen(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, open) <= 0) return signal;
    if(CopyTickVolume(InpSymbol, (ENUM_TIMEFRAMES)InpBBTimeframe, 0, 5, volume) <= 0) return signal;
    
    // Check for NaN
    if(!MathIsValidNumber(bbUpper[0]) || !MathIsValidNumber(bbLower[0]) ||
       !MathIsValidNumber(rsiValue) || !MathIsValidNumber(atrValue))
    {
        if(InpDebugMode)
            Print("DetectMeanRevSignal: Invalid indicator data (NaN)");
        return signal;
    }
    
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    double askPrice = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
    
    // Calculate VWAP if enabled
    double vwapValue = 0;
    if(InpUseVWAP)
    {
        vwapValue = CalculateVWAP();
    }
    
    // Calculate Bollinger Band width
    double bbWidth = (bbUpper[0] - bbLower[0]) / point;
    double bbWidthPrev = (bbUpper[1] - bbLower[1]) / point;
    bool bbExpanded = (bbWidth > bbWidthPrev);
    
    // Calculate price position relative to bands
    double priceBelowLower = (close[0] < bbLower[0]);
    double priceAboveUpper = (close[0] > bbUpper[0]);
    
    // Calculate ATR validity
    bool atrValid = (atrValue >= InpMinVolatility * point) && (atrValue <= InpMaxVolatility * point);
    if(!atrValid)
        return signal;
    
    double atrPoints = atrValue / point;
    
    // Volume exhaustion check
    double volumeSpikeThreshold = volumeMA[0] * InpVolumeSpikeMultiplier;
    bool volumeLow = (volume[0] < volumeMA[0] * 0.7);
    bool volumeExhausted = volumeLow;
    
    // RSI extreme detection
    bool rsiExtremeOversold = (rsiValue < InpRSIOversold);
    bool rsiExtremeOverbought = (rsiValue > InpRSIOverbought);
    
    // Pin bar / rejection candle detection
    double bodySize = MathAbs(close[0] - open[0]) / point;
    double upperWick = (high[0] - MathMax(open[0], close[0])) / point;
    double lowerWick = (MathMin(open[0], close[0]) - low[0]) / point;
    
    bool bullishPinBar = (lowerWick > bodySize * 2) && (upperWick < bodySize * 0.5) && (close[0] > open[0]);
    bool bearishPinBar = (upperWick > bodySize * 2) && (lowerWick < bodySize * 0.5) && (close[0] < open[0]);
    
    // VWAP distance check
    bool priceAboveVWAP = (vwapValue > 0) && (close[0] > vwapValue);
    bool priceBelowVWAP = (vwapValue > 0) && (close[0] < vwapValue);
    
    // Calculate confidence and build signals
    int confirmations = 0;
    string signalDescription = "";
    
    // BUY SIGNAL (Mean Reversion - Price at lower band expecting bounce)
    if(priceBelowLower && atrValid)
    {
        confirmations = 0;
        signalDescription = "";
        
        if(rsiExtremeOversold) { confirmations++; signalDescription += "RSI Oversold "; }
        if(volumeExhausted) { confirmations++; signalDescription += "Vol Exhausted "; }
        if(bullishPinBar) { confirmations++; signalDescription += "Bull PinBar "; }
        if(bbExpanded) { confirmations++; signalDescription += "BB Expanding "; }
        if(!InpUseVWAP || priceAboveVWAP) { confirmations++; signalDescription += "Above VWAP "; }
        
        double confidence = (double)confirmations / 5.0 * 100;
        
        if(confirmations >= InpMinConfirmations)
        {
            // Calculate SL and TP for mean reversion
            double slDistance = atrPoints * InpATRSLMultiplier * 1.2;
            double tpDistance = atrPoints * InpATRTPMultiplier;
            
            slDistance = MathMax(slDistance, InpMinTradeDistance);
            tpDistance = MathMax(tpDistance, InpMinTradeDistance * 2);
            
            double stopLoss = NormalizeDouble(askPrice - slDistance * point, _Digits);
            double takeProfit = NormalizeDouble(askPrice + tpDistance * point, _Digits);
            
            signal.buySignal = true;
            signal.sellSignal = false;
            signal.confidence = confidence;
            signal.confirmations = confirmations;
            signal.quality = (confidence >= 80) ? SIGNAL_VERY_STRONG : 
                             (confidence >= 60) ? SIGNAL_STRONG : SIGNAL_MODERATE;
            signal.entryPrice = askPrice;
            signal.stopLoss = stopLoss;
            signal.takeProfit = takeProfit;
            signal.timestamp = TimeCurrent();
            signal.description = "[MEAN_REV/BUY] " + signalDescription;
        }
    }
    
    // SELL SIGNAL (Mean Reversion - Price at upper band expecting drop)
    if(priceAboveUpper && atrValid)
    {
        confirmations = 0;
        signalDescription = "";
        
        if(rsiExtremeOverbought) { confirmations++; signalDescription += "RSI Overbought "; }
        if(volumeExhausted) { confirmations++; signalDescription += "Vol Exhausted "; }
        if(bearishPinBar) { confirmations++; signalDescription += "Bear PinBar "; }
        if(bbExpanded) { confirmations++; signalDescription += "BB Expanding "; }
        if(!InpUseVWAP || priceBelowVWAP) { confirmations++; signalDescription += "Below VWAP "; }
        
        double confidence = (double)confirmations / 5.0 * 100;
        
        if(confirmations >= InpMinConfirmations)
        {
            double slDistance = atrPoints * InpATRSLMultiplier * 1.2;
            double tpDistance = atrPoints * InpATRTPMultiplier;
            
            slDistance = MathMax(slDistance, InpMinTradeDistance);
            tpDistance = MathMax(tpDistance, InpMinTradeDistance * 2);
            
            double stopLoss = NormalizeDouble(bidPrice + slDistance * point, _Digits);
            double takeProfit = NormalizeDouble(bidPrice - tpDistance * point, _Digits);
            
            signal.sellSignal = true;
            signal.buySignal = false;
            signal.confidence = confidence;
            signal.confirmations = confirmations;
            signal.quality = (confidence >= 80) ? SIGNAL_VERY_STRONG : 
                             (confidence >= 60) ? SIGNAL_STRONG : SIGNAL_MODERATE;
            signal.entryPrice = bidPrice;
            signal.stopLoss = stopLoss;
            signal.takeProfit = takeProfit;
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
    
    // Get session start
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime sessionStart;
    
    if(InpVWAPSession == 0) // Daily VWAP
    {
        sessionStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    }
    else // Weekly VWAP
    {
        int dayOfWeek = dt.day_of_week;
        int daysToSubtract = dayOfWeek - 1;
        if(daysToSubtract < 0) daysToSubtract += 7;
        sessionStart = StringToTime(TimeToString(TimeCurrent() - daysToSubtract * 86400, TIME_DATE));
    }
    
    // Calculate VWAP from session start
    int bars = Bars(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, sessionStart, TimeCurrent());
    if(bars <= 0 || bars > 500)
        bars = 500;
    
    double closePrices[], highPrices[], lowPrices[], volumePrices[];
    ArraySetAsSeries(closePrices, true);
    ArraySetAsSeries(highPrices, true);
    ArraySetAsSeries(lowPrices, true);
    ArraySetAsSeries(volumePrices, true);
    
    if(CopyClose(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, bars, closePrices) <= 0)
        return 0;
    if(CopyHigh(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, bars, highPrices) <= 0)
        return 0;
    if(CopyLow(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, bars, lowPrices) <= 0)
        return 0;
    if(CopyTickVolume(InpSymbol, (ENUM_TIMEFRAMES)InpTrendTimeframe, 0, bars, volumePrices) <= 0)
        return 0;
    
    // Calculate typical price and weighted volume
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
//| CHECK DXY FILTER                                                  |
//+------------------------------------------------------------------+
bool CheckDXYFilter()
{
    if(!InpUseDXYFilter)
        return true;
    
    double dxyRSI[];
    ArraySetAsSeries(dxyRSI, true);
    
    int dxyHandle = iRSI(InpDXYSymbol, PERIOD_H1, 14, PRICE_CLOSE);
    if(dxyHandle == INVALID_HANDLE)
        return true; // Default to pass if DXY not available
    
    if(CopyBuffer(dxyHandle, 0, 0, 2, dxyRSI) <= 0)
    {
        IndicatorRelease(dxyHandle);
        return true;
    }
    IndicatorRelease(dxyHandle);
    
    // Check if RSI is in extreme zone
    if(dxyRSI[0] > 70 || dxyRSI[0] < 30)
        return false; // Block trade during DXY extremes
    
    return true;
}

//+------------------------------------------------------------------+
//| CHECK VIX FILTER                                                  |
//+------------------------------------------------------------------+
bool CheckVIXFilter()
{
    if(!InpUseVIXFilter)
        return true;
    
    double atrCurrent;
    if(CopyBuffer(g_handleATR, 0, 0, 1, atrCurrent) <= 0)
        return true;
    
    // Simple VIX estimation: Compare current ATR to average
    double atrMA;
    int atrMaHandle = iMA(InpSymbol, PERIOD_D1, 20, 0, MODE_SMA, PRICE_CLOSE);
    if(atrMaHandle != INVALID_HANDLE)
    {
        double atrMaBuffer[];
        ArraySetAsSeries(atrMaBuffer, true);
        if(CopyBuffer(atrMaHandle, 0, 0, 2, atrMaBuffer) <= 0)
        {
            IndicatorRelease(atrMaHandle);
            return true;
        }
        atrMA = atrMaBuffer[0];
        IndicatorRelease(atrMaHandle);
        
        // Simple VIX estimation: High ATR relative to MA suggests high VIX
        if(atrCurrent > atrMA * 2)
            return false; // High volatility - skip
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| EXECUTE TRADE                                                    |
//+------------------------------------------------------------------+
bool ExecuteTrade(STradeSignal &signal)
{
    if(!signal.buySignal && !signal.sellSignal)
        return false;
    
    // Validate signal values
    if(!MathIsValidNumber(signal.entryPrice) || !MathIsValidNumber(signal.stopLoss) || 
       !MathIsValidNumber(signal.takeProfit))
    {
        if(InpDebugMode)
            Print("ERROR: Invalid signal values - NaN detected");
        return false;
    }
    
    // Calculate lot size based on risk management
    double lotSize = CalculateLotSize(signal.stopLoss, signal.entryPrice);
    if(lotSize < SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN))
    {
        if(InpDebugMode)
            Print("ERROR: Calculated lot size below minimum");
        return false;
    }
    
    // Normalize lot to broker requirements
    lotSize = NormalizeLot(lotSize);
    
    // Get current prices
    double price = signal.entryPrice;
    double sl = signal.stopLoss;
    double tp = signal.takeProfit;
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    
    // Validate SL/TP distances
    double minDistance = SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    if(MathAbs(price - sl) < minDistance || MathAbs(price - tp) < minDistance)
    {
        if(InpDebugMode)
            Print("ERROR: SL/TP too close to entry price");
        return false;
    }
    
    // Execute the trade
    bool result = false;
    if(signal.buySignal)
    {
        result = g_trade.Buy(lotSize, InpSymbol, price, sl, tp, signal.description);
    }
    else
    {
        result = g_trade.Sell(lotSize, InpSymbol, price, sl, tp, signal.description);
    }
    
    // Handle trade result
    if(result)
    {
        ulong ticket = g_trade.ResultOrder();
        
        if(InpVerboseLogging)
        {
            Print("===========================================");
            Print("TRADE OPENED SUCCESSFULLY");
            Print("Ticket: ", ticket);
            Print("Type: ", signal.buySignal ? "BUY" : "SELL");
            Print("Symbol: ", InpSymbol);
            Print("Lot Size: ", DoubleToString(lotSize, 2));
            Print("Entry Price: ", DoubleToString(price, _Digits));
            Print("Stop Loss: ", DoubleToString(sl, _Digits));
            Print("Take Profit: ", DoubleToString(tp, _Digits));
            Print("Confidence: ", DoubleToString(signal.confidence, 1), "%");
            Print("Confirmations: ", signal.confirmations);
            Print("Description: ", signal.description);
            Print("===========================================");
        }
        
        g_lastTradeTime = TimeCurrent();
    }
    else
    {
        if(InpDebugMode)
        {
            Print("ERROR: Trade execution failed");
            Print("Result Code: ", g_trade.ResultRetcode());
            Print("Result Comment: ", g_trade.ResultComment());
        }
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| CALCULATE LOT SIZE                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLoss, double entryPrice)
{
    double lotSize;
    
    // If fixed lot is specified, use it
    if(InpFixedLot > 0)
    {
        lotSize = InpFixedLot;
    }
    else
    {
        // Calculate based on risk percentage
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * (InpRiskPercent / 100.0);
        
        // Calculate distance to stop loss in points
        double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
        double stopLossDistance = MathAbs(entryPrice - stopLoss) / point;
        
        // Get tick value for risk calculation
        double tickValue = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
        
        // Calculate risk per lot
        double riskPerPoint = (stopLossDistance * tickValue) / tickSize;
        
        if(riskPerPoint > 0)
        {
            lotSize = riskAmount / riskPerPoint;
        }
        else
        {
            lotSize = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
        }
        
        // Apply lot constraints
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
    
    // Round to lot step
    if(lotStep > 0)
        lot = MathRound(lot / lotStep) * lotStep;
    
    // Apply constraints
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
    if(ticket == 0)
        return;
    
    if(!PositionSelectByTicket(ticket))
        return;
    
    // Get position details
    double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double positionCurrentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double positionSL = PositionGetDouble(POSITION_SL);
    double positionTP = PositionGetDouble(POSITION_TP);
    ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double volume = PositionGetDouble(POSITION_VOLUME);
    
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    
    // Get ATR for trailing calculations
    double atrValue;
    if(CopyBuffer(g_handleATR, 0, 0, 1, atrValue) <= 0)
        return;
    
    double atrPoints = atrValue / point;
    
    // Calculate break-even level
    double breakEvenLevel;
    if(positionType == POSITION_TYPE_BUY)
    {
        breakEvenLevel = positionOpenPrice + (atrPoints * InpBreakEvenTrigger * point);
    }
    else
    {
        breakEvenLevel = positionOpenPrice - (atrPoints * InpBreakEvenTrigger * point);
    }
    
    // Check for break-even
    if(InpBreakEvenTrigger > 0 && positionSL != 0)
    {
        bool shouldSetBreakEven = false;
        if(positionType == POSITION_TYPE_BUY && positionCurrentPrice >= breakEvenLevel && positionSL < positionOpenPrice)
        {
            shouldSetBreakEven = true;
        }
        else if(positionType == POSITION_TYPE_SELL && positionCurrentPrice <= breakEvenLevel && positionSL > positionOpenPrice)
        {
            shouldSetBreakEven = true;
        }
        
        if(shouldSetBreakEven)
        {
            double newSL;
            if(positionType == POSITION_TYPE_BUY)
            {
                newSL = NormalizeDouble(positionOpenPrice + (InpBreakEvenBuffer * atrPoints * point), _Digits);
                if(newSL > positionSL)
                {
                    g_trade.PositionModify(ticket, newSL, positionTP);
                    if(InpDebugMode)
                        Print("Break-even set: New SL = ", DoubleToString(newSL, _Digits));
                }
            }
            else
            {
                newSL = NormalizeDouble(positionOpenPrice - (InpBreakEvenBuffer * atrPoints * point), _Digits);
                if(newSL < positionSL)
                {
                    g_trade.PositionModify(ticket, newSL, positionTP);
                    if(InpDebugMode)
                        Print("Break-even set: New SL = ", DoubleToString(newSL, _Digits));
                }
            }
        }
    }
    
    // Check for partial close at TP1
    if(InpUsePartialClose)
    {
        double tp1Level;
        if(positionType == POSITION_TYPE_BUY)
        {
            tp1Level = positionOpenPrice + (atrPoints * InpATRTPMultiplier * InpTP1Percent / 100.0 * point);
        }
        else
        {
            tp1Level = positionOpenPrice - (atrPoints * InpATRTPMultiplier * InpTP1Percent / 100.0 * point);
        }
        
        bool reachedTP1 = false;
        if(positionType == POSITION_TYPE_BUY && positionCurrentPrice >= tp1Level)
            reachedTP1 = true;
        else if(positionType == POSITION_TYPE_SELL && positionCurrentPrice <= tp1Level)
            reachedTP1 = true;
        
        if(reachedTP1)
        {
            double closeVolume = volume * (InpPartialClosePercent / 100.0);
            closeVolume = NormalizeLot(closeVolume);
            
            double minVol = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
            if(closeVolume >= minVol)
            {
                if(g_trade.PositionClosePartial(ticket, closeVolume))
                {
                    if(InpVerboseLogging)
                        Print("Partial close executed at TP1: Volume closed = ", DoubleToString(closeVolume, 2));
                }
            }
        }
    }
    
    // Check for trailing stop
    if(InpUseTrailingStop)
    {
        double trailStart;
        if(positionType == POSITION_TYPE_BUY)
        {
            trailStart = positionOpenPrice + (atrPoints * InpATRTPMultiplier * InpTrailStartPercent / 100.0 * point);
            
            if(positionCurrentPrice >= trailStart)
            {
                double newTrailingSL = positionCurrentPrice - (atrPoints * InpATRSLMultiplier * InpTrailDistancePercent / 100.0 * point);
                newTrailingSL = NormalizeDouble(newTrailingSL, _Digits);
                
                if(newTrailingSL > positionSL)
                {
                    g_trade.PositionModify(ticket, newTrailingSL, positionTP);
                    if(InpDebugMode)
                        Print("Trailing stop updated: New SL = ", DoubleToString(newTrailingSL, _Digits));
                }
            }
        }
        else
        {
            trailStart = positionOpenPrice - (atrPoints * InpATRTPMultiplier * InpTrailStartPercent / 100.0 * point);
            
            if(positionCurrentPrice <= trailStart)
            {
                double newTrailingSL = positionCurrentPrice + (atrPoints * InpATRSLMultiplier * InpTrailDistancePercent / 100.0 * point);
                newTrailingSL = NormalizeDouble(newTrailingSL, _Digits);
                
                if(newTrailingSL < positionSL || positionSL == 0)
                {
                    g_trade.PositionModify(ticket, newTrailingSL, positionTP);
                    if(InpDebugMode)
                        Print("Trailing stop updated: New SL = ", DoubleToString(newTrailingSL, _Digits));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| CHECK TRADE RESULT & UPDATE TRACKING                             |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
    // Handle trade transaction events
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        ulong dealTicket = trans.deal;
        if(dealTicket > 0)
        {
            long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            if(dealMagic == InpMagicNumber)
            {
                double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                
                // Update daily profit
                g_dailyProfit += dealProfit;
                
                // Update consecutive losses
                if(dealProfit < 0)
                {
                    g_consecutiveLosses++;
                    if(InpVerboseLogging)
                        Print("Loss recorded. Consecutive losses: ", g_consecutiveLosses);
                }
                else
                {
                    g_consecutiveLosses = 0;
                }
                
                if(InpVerboseLogging)
                {
                    Print("Deal closed: ", dealTicket);
                    Print("Deal Profit: ", DoubleToString(dealProfit, 2));
                    Print("Daily P&L: ", DoubleToString(g_dailyProfit, 2));
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
    // Emergency close all trades on F12
    if(id == CHARTEVENT_KEYDOWN)
    {
        if(lparam == 123) // F12 key
        {
            CloseAllTrades();
        }
    }
}

//+------------------------------------------------------------------+
//| CLOSE ALL TRADES (Emergency)                                     |
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
            if(InpDebugMode)
                Print("Emergency close: Ticket ", ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| PRINT STATISTICS (For optimization)                               |
//+------------------------------------------------------------------+
void PrintStatistics()
{
    double totalProfit = 0;
    int totalTrades = 0;
    int winningTrades = 0;
    int losingTrades = 0;
    
    // Get history
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
            
            if(profit > 0)
                winningTrades++;
            else if(profit < 0)
                losingTrades++;
        }
    }
    
    HistorySelect(0, TimeCurrent());
    
    if(totalTrades > 0)
    {
        double winRate = (double)winningTrades / totalTrades * 100;
        double avgWin = (totalProfit / totalTrades);
        
        Print("===========================================");
        Print("EXPERIMENTAL STATISTICS");
        Print("Total Trades: ", totalTrades);
        Print("Winning Trades: ", winningTrades);
        Print("Losing Trades: ", losingTrades);
        Print("Win Rate: ", DoubleToString(winRate, 2), "%");
        Print("Total Profit: ", DoubleToString(totalProfit, 2));
        Print("Average P&L: ", DoubleToString(avgWin, 2));
        Print("===========================================");
    }
}

//+------------------------------------------------------------------+
//| END OF EXPERT ADVISOR                                            |
//+------------------------------------------------------------------+

