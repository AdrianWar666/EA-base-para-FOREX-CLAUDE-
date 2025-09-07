//+------------------------------------------------------------------+
//|                                            HybridEmperor_EA.mq5  |
//|                              Copyright PrimeBot 2025             |
//|                     https://www.primebotportfolio.com.br/        |
//+------------------------------------------------------------------+
#property copyright "Copyright PrimeBot 2025"
#property link      "https://www.primebotportfolio.com.br/"
#property version   "1.00"
#property description "Hybrid Emperor EA - Combinando as melhores estratégias"
#property description "Virtual Trades + Split Positions + VWAP Confirmation"

// Incluir bibliotecas do sistema PrimeBot
#include <PrimeBot\PrimeBotBase.mqh>
#include <PrimeBot\PrimeBotLicense.mqh>
#include <PrimeBot\PrimeBotPanel.mqh>

//--- Parâmetros de entrada
input group "═══ CONFIGURAÇÃO DA LICENÇA ═══"
input string   InpLicenseAccount = "0";                    // Conta Autorizada (0 = Universal)
input datetime InpLicenseExpiration = D'2025.12.31';       // Data de Expiração

input group "═══ CONFIGURAÇÕES PRINCIPAIS ═══"
input int      InpMagicNumber = 123456;                    // Magic Number
input double   InpRiskPercent = 1.0;                       // Risco por Operação (%)
input double   InpInitialLot = 0.01;                       // Lote Inicial
input bool     InpUseMoneyManagement = true;              // Usar Gerenciamento de Risco

input group "═══ ESTRATÉGIA VIRTUAL TRADES (FOREX FLEX) ═══"
input bool     InpUseVirtualTrades = true;                 // Usar Virtual Trades
input int      InpVirtualPeriod = 10;                      // Período de Análise Virtual
input double   InpVirtualMinWinRate = 60.0;                // Taxa Mínima de Acerto Virtual (%)

input group "═══ ESTRATÉGIA SPLIT POSITIONS (QUANTUM EMPEROR) ═══"
input bool     InpUseSplitPositions = true;                // Usar Divisão de Posições
input int      InpSplitCount = 5;                          // Número de Divisões
input double   InpSplitMultiplier = 1.2;                   // Multiplicador de Recuperação
input int      InpRecoveryDistance = 20;                   // Distância de Recuperação (pontos)

input group "═══ CONFIRMAÇÃO VWAP (GOLDFISH) ═══"
input bool     InpUseVWAPConfirmation = true;              // Usar Confirmação VWAP
input int      InpVWAPPeriod = 20;                         // Período VWAP

input group "═══ INDICADORES TÉCNICOS ═══"
input int      InpADXPeriod = 14;                          // Período ADX
input double   InpADXLevel = 25.0;                         // Nível Mínimo ADX
input int      InpRSIPeriod = 14;                          // Período RSI
input double   InpRSIOverbought = 70.0;                    // RSI Sobrecomprado
input double   InpRSIOversold = 30.0;                      // RSI Sobrevendido

input group "═══ GERENCIAMENTO DE RISCO ═══"
input int      InpStopLoss = 100;                          // Stop Loss (pontos)
input int      InpTakeProfit = 150;                        // Take Profit (pontos)
input double   InpTrailingStart = 50;                      // Início do Trailing (pontos)
input double   InpTrailingStep = 10;                       // Passo do Trailing (pontos)
input bool     InpUseEmergencyHedge = true;                // Usar Hedge de Emergência
input double   InpHedgeDrawdown = 5.0;                     // Drawdown para Hedge (%)

input group "═══ FILTROS DE TEMPO ═══"
input bool     InpUseTimeFilter = true;                    // Usar Filtro de Horário
input int      InpStartHour = 9;                           // Hora de Início
input int      InpStartMinute = 0;                         // Minuto de Início
input int      InpEndHour = 17;                            // Hora de Término
input int      InpEndMinute = 0;                           // Minuto de Término
input bool     InpTradeFriday = false;                     // Operar Sexta-feira
input int      InpMaxDailyTrades = 10;                     // Máximo de Trades por Dia (0 = ilimitado)

input group "═══ CONFIGURAÇÕES DO PAINEL ═══"
input bool     InpShowPanel = true;                        // Mostrar Painel
input int      InpPanelCorner = CORNER_LEFT_UPPER;         // Canto do Painel
input int      InpPanelX = 20;                             // Posição X
input int      InpPanelY = 20;                             // Posição Y

//--- Objetos do sistema
CPrimeBotBase     *base;
CPrimeBotLicense  *license;
CPrimeBotPanel    *panel;

//--- Handles dos indicadores
int handle_adx;
int handle_rsi;
int handle_vwap;

//--- Buffers dos indicadores
double adx_main[], adx_plus[], adx_minus[];
double rsi_buffer[];
double vwap_buffer[];

//--- Estrutura para Virtual Trades
struct VirtualTrade
{
   datetime time;
   double   entry_price;
   int      type;           // 0=Buy, 1=Sell
   double   profit;
   bool     closed;
};
VirtualTrade virtual_trades[];
int virtual_trade_count = 0;
double virtual_win_rate = 0;

//--- Estrutura para Split Positions
struct SplitPosition
{
   ulong    tickets[];      // Array de tickets das posições divididas
   double   lots[];         // Array de lotes
   double   entry_prices[]; // Preços de entrada
   int      count;          // Número de divisões ativas
   double   recovery_level; // Nível de recuperação
   bool     in_recovery;    // Em modo recuperação
};
SplitPosition split_positions;

//--- Variáveis de controle
datetime last_bar_time = 0;
bool     hedge_active = false;
int      daily_trades = 0;
datetime last_day = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Criar objetos do sistema
   base = new CPrimeBotBase();
   license = new CPrimeBotLicense();
   panel = new CPrimeBotPanel();
   
   //--- Configurar e verificar licença
   license.SetLicense(InpLicenseAccount, InpLicenseExpiration);
   if(!license.CheckLicense())
   {
      license.PrintLicenseInfo();
      return INIT_FAILED;
   }
   license.PrintLicenseInfo();
   
   //--- Inicializar sistema base
   if(!base.Init(_Symbol, _Period, InpMagicNumber))
   {
      Print("❌ Erro ao inicializar sistema base: ", base.GetLastError());
      return INIT_FAILED;
   }
   
   //--- Criar indicadores
   handle_adx = iADX(_Symbol, _Period, InpADXPeriod);
   handle_rsi = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   
   // VWAP customizado (simulado com média móvel ponderada por volume)
   handle_vwap = iMA(_Symbol, _Period, InpVWAPPeriod, 0, MODE_LWMA, PRICE_TYPICAL);
   
   if(handle_adx == INVALID_HANDLE || handle_rsi == INVALID_HANDLE || handle_vwap == INVALID_HANDLE)
   {
      Print("❌ Erro ao criar indicadores");
      return INIT_FAILED;
   }
   
   //--- Configurar arrays como séries temporais
   ArraySetAsSeries(adx_main, true);
   ArraySetAsSeries(adx_plus, true);
   ArraySetAsSeries(adx_minus, true);
   ArraySetAsSeries(rsi_buffer, true);
   ArraySetAsSeries(vwap_buffer, true);
   
   //--- Inicializar arrays de virtual trades
   ArrayResize(virtual_trades, 100);
   virtual_trade_count = 0;
   
   //--- Inicializar estrutura de split positions
   ArrayResize(split_positions.tickets, InpSplitCount);
   ArrayResize(split_positions.lots, InpSplitCount);
   ArrayResize(split_positions.entry_prices, InpSplitCount);
   split_positions.count = 0;
   split_positions.in_recovery = false;
   
   //--- Criar painel se habilitado
   if(InpShowPanel)
   {
      panel.Configure("HYBRID EMPEROR EA", InpPanelCorner, InpPanelX, InpPanelY);
      panel.CreatePanel();
      UpdatePanel();
   }
   
   //--- Mensagem de sucesso
   Print("✅ Hybrid Emperor EA inicializado com sucesso");
   Print("   Virtual Trades: ", InpUseVirtualTrades ? "ATIVO" : "INATIVO");
   Print("   Split Positions: ", InpUseSplitPositions ? "ATIVO" : "INATIVO");
   Print("   VWAP Confirmation: ", InpUseVWAPConfirmation ? "ATIVO" : "INATIVO");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Deletar objetos
   if(base != NULL) delete base;
   if(license != NULL) delete license;
   if(panel != NULL) delete panel;
   
   //--- Deletar indicadores
   if(handle_adx != INVALID_HANDLE) IndicatorRelease(handle_adx);
   if(handle_rsi != INVALID_HANDLE) IndicatorRelease(handle_rsi);
   if(handle_vwap != INVALID_HANDLE) IndicatorRelease(handle_vwap);
   
   Print("✅ Hybrid Emperor EA finalizado");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Verificar licença periodicamente
   static datetime last_license_check = 0;
   if(TimeCurrent() - last_license_check > 3600) // Verificar a cada hora
   {
      if(!license.CheckLicense())
      {
         ExpertRemove();
         return;
      }
      last_license_check = TimeCurrent();
   }
   
   //--- Atualizar estatísticas
   base.UpdateStatistics();
   
   //--- Verificar novo dia
   datetime current_day = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(current_day != last_day)
   {
      last_day = current_day;
      daily_trades = 0;
   }
   
   //--- Verificar limite diário
   if(InpMaxDailyTrades > 0 && daily_trades >= InpMaxDailyTrades)
   {
      if(InpShowPanel) UpdatePanel();
      return;
   }
   
   //--- Verificar filtro de tempo
   if(InpUseTimeFilter)
   {
      if(!base.IsTimeToTrade(InpStartHour, InpStartMinute, InpEndHour, InpEndMinute))
      {
         if(InpShowPanel) UpdatePanel();
         return;
      }
      
      // Não operar sexta-feira se configurado
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(!InpTradeFriday && dt.day_of_week == 5)
      {
         if(InpShowPanel) UpdatePanel();
         return;
      }
   }
   
   //--- Gerenciar posições existentes
   ManagePositions();
   
   //--- Verificar hedge de emergência
   if(InpUseEmergencyHedge)
   {
      CheckEmergencyHedge();
   }
   
   //--- Verificar nova barra para análise
   if(!base.IsNewBar())
   {
      if(InpShowPanel) UpdatePanel();
      return;
   }
   
   //--- Copiar dados dos indicadores
   if(!CopyIndicatorData())
   {
      if(InpShowPanel) UpdatePanel();
      return;
   }
   
   //--- Analisar virtual trades se habilitado
   if(InpUseVirtualTrades)
   {
      AnalyzeVirtualTrades();
   }
   
   //--- Verificar sinais de entrada
   int signal = GetTradingSignal();
   
   if(signal != 0)
   {
      ExecuteTrade(signal);
   }
   
   //--- Atualizar painel
   if(InpShowPanel) UpdatePanel();
}

//+------------------------------------------------------------------+
//| Copiar dados dos indicadores                                    |
//+------------------------------------------------------------------+
bool CopyIndicatorData()
{
   if(CopyBuffer(handle_adx, 0, 0, 3, adx_main) <= 0) return false;
   if(CopyBuffer(handle_adx, 1, 0, 3, adx_plus) <= 0) return false;
   if(CopyBuffer(handle_adx, 2, 0, 3, adx_minus) <= 0) return false;
   if(CopyBuffer(handle_rsi, 0, 0, 3, rsi_buffer) <= 0) return false;
   if(CopyBuffer(handle_vwap, 0, 0, 3, vwap_buffer) <= 0) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Obter sinal de trading                                          |
//+------------------------------------------------------------------+
int GetTradingSignal()
{
   // Verificar força da tendência com ADX
   if(adx_main[0] < InpADXLevel) return 0; // Sem tendência forte
   
   int signal = 0;
   
   // Sinal de compra
   if(adx_plus[0] > adx_minus[0] && 
      rsi_buffer[0] < InpRSIOverbought && 
      rsi_buffer[1] < InpRSIOversold && rsi_buffer[0] > rsi_buffer[1])
   {
      signal = 1;
   }
   // Sinal de venda
   else if(adx_minus[0] > adx_plus[0] && 
           rsi_buffer[0] > InpRSIOversold && 
           rsi_buffer[1] > InpRSIOverbought && rsi_buffer[0] < rsi_buffer[1])
   {
      signal = -1;
   }
   
   // Confirmar com VWAP se habilitado
   if(signal != 0 && InpUseVWAPConfirmation)
   {
      double close_price = iClose(_Symbol, _Period, 0);
      
      if(signal == 1 && close_price < vwap_buffer[0])
         signal = 0; // Cancelar compra se preço abaixo do VWAP
      else if(signal == -1 && close_price > vwap_buffer[0])
         signal = 0; // Cancelar venda se preço acima do VWAP
   }
   
   // Verificar virtual trades se habilitado
   if(signal != 0 && InpUseVirtualTrades)
   {
      if(virtual_win_rate < InpVirtualMinWinRate)
         signal = 0; // Cancelar se win rate virtual baixo
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//| Executar trade                                                  |
//+------------------------------------------------------------------+
void ExecuteTrade(int signal)
{
   // Verificar se já existe posição
   if(base.CountPositions() > 0) return;
   
   // Calcular lote
   double lot = InpInitialLot;
   if(InpUseMoneyManagement)
   {
      lot = base.CalculateLotByRisk(InpRiskPercent, InpStopLoss);
   }
   
   // Preparar trade
   CTrade trade;
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   double price = (signal == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0, tp = 0;
   
   if(InpStopLoss > 0)
   {
      sl = (signal == 1) ? price - InpStopLoss * _Point : price + InpStopLoss * _Point;
   }
   
   if(InpTakeProfit > 0)
   {
      tp = (signal == 1) ? price + InpTakeProfit * _Point : price - InpTakeProfit * _Point;
   }
   
   // Usar split positions se habilitado
   if(InpUseSplitPositions)
   {
      ExecuteSplitTrade(signal, lot, sl, tp);
   }
   else
   {
      // Trade normal
      bool result = false;
      if(signal == 1)
         result = trade.Buy(lot, _Symbol, price, sl, tp, "Hybrid Emperor BUY");
      else
         result = trade.Sell(lot, _Symbol, price, sl, tp, "Hybrid Emperor SELL");
      
      if(result)
      {
         daily_trades++;
         Print("✅ Trade executado: ", signal == 1 ? "BUY" : "SELL", " Lote: ", lot);
         
         // Adicionar como virtual trade para análise futura
         if(InpUseVirtualTrades)
         {
            AddVirtualTrade(signal, price);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Executar trade com split positions                              |
//+------------------------------------------------------------------+
void ExecuteSplitTrade(int signal, double total_lot, double sl, double tp)
{
   CTrade trade;
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Dividir lote total
   double split_lot = base.NormalizeLot(total_lot / InpSplitCount);
   
   split_positions.count = 0;
   split_positions.in_recovery = false;
   
   for(int i = 0; i < InpSplitCount; i++)
   {
      double price = (signal == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      bool result = false;
      if(signal == 1)
         result = trade.Buy(split_lot, _Symbol, price, sl, tp, "Split " + IntegerToString(i+1));
      else
         result = trade.Sell(split_lot, _Symbol, price, sl, tp, "Split " + IntegerToString(i+1));
      
      if(result)
      {
         split_positions.tickets[i] = trade.ResultOrder();
         split_positions.lots[i] = split_lot;
         split_positions.entry_prices[i] = price;
         split_positions.count++;
      }
      
      // Pequeno delay entre ordens
      Sleep(100);
   }
   
   if(split_positions.count > 0)
   {
      daily_trades++;
      Print("✅ Split trade executado: ", signal == 1 ? "BUY" : "SELL", 
            " Divisões: ", split_positions.count, " Lote total: ", split_lot * split_positions.count);
   }
}

//+------------------------------------------------------------------+
//| Gerenciar posições abertas                                      |
//+------------------------------------------------------------------+
void ManagePositions()
{
   // Trailing stop
   if(InpTrailingStart > 0)
   {
      ApplyTrailingStop();
   }
   
   // Gerenciar split positions se ativo
   if(InpUseSplitPositions && split_positions.count > 0)
   {
      ManageSplitPositions();
   }
}

//+------------------------------------------------------------------+
//| Aplicar trailing stop                                           |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   CPositionInfo position;
   CTrade trade;
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Magic() != InpMagicNumber) continue;
         if(position.Symbol() != _Symbol) continue;
         
         double current_sl = position.StopLoss();
         double current_price = position.PriceCurrent();
         double open_price = position.PriceOpen();
         
         if(position.PositionType() == POSITION_TYPE_BUY)
         {
            if(current_price - open_price >= InpTrailingStart * _Point)
            {
               double new_sl = current_price - InpTrailingStep * _Point;
               if(new_sl > current_sl)
               {
                  trade.PositionModify(position.Ticket(), new_sl, position.TakeProfit());
               }
            }
         }
         else // SELL
         {
            if(open_price - current_price >= InpTrailingStart * _Point)
            {
               double new_sl = current_price + InpTrailingStep * _Point;
               if(new_sl < current_sl || current_sl == 0)
               {
                  trade.PositionModify(position.Ticket(), new_sl, position.TakeProfit());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gerenciar split positions                                       |
//+------------------------------------------------------------------+
void ManageSplitPositions()
{
   // Implementar lógica de recuperação estilo Quantum Emperor
   // Usar lucros das posições vencedoras para fechar perdedoras gradualmente
   
   double total_profit = 0;
   int profitable_count = 0;
   
   CPositionInfo position;
   
   // Calcular lucro total e contar posições lucrativas
   for(int i = 0; i < split_positions.count; i++)
   {
      if(position.SelectByTicket(split_positions.tickets[i]))
      {
         double profit = position.Profit();
         total_profit += profit;
         
         if(profit > 0) profitable_count++;
      }
   }
   
   // Se temos lucro suficiente, começar a fechar posições perdedoras
   if(profitable_count > split_positions.count / 2 && total_profit > 0)
   {
      CTrade trade;
      trade.SetExpertMagicNumber(InpMagicNumber);
      
      for(int i = 0; i < split_positions.count; i++)
      {
         if(position.SelectByTicket(split_positions.tickets[i]))
         {
            if(position.Profit() < 0 && total_profit > MathAbs(position.Profit()))
            {
               if(trade.PositionClose(split_positions.tickets[i]))
               {
                  Print("✅ Posição perdedora fechada usando lucros: Ticket ", split_positions.tickets[i]);
                  split_positions.tickets[i] = 0;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar hedge de emergência                                   |
//+------------------------------------------------------------------+
void CheckEmergencyHedge()
{
   if(hedge_active) return;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double drawdown_percent = ((balance - equity) / balance) * 100;
   
   if(drawdown_percent >= InpHedgeDrawdown)
   {
      // Abrir hedge para proteger conta
      int current_positions = base.CountPositions();
      
      if(current_positions > 0)
      {
         CTrade trade;
         trade.SetExpertMagicNumber(InpMagicNumber);
         
         // Calcular lote total das posições abertas
         double total_lots = 0;
         CPositionInfo position;
         ENUM_POSITION_TYPE main_type = POSITION_TYPE_BUY;
         
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(position.SelectByIndex(i))
            {
               if(position.Magic() != InpMagicNumber) continue;
               if(position.Symbol() != _Symbol) continue;
               
               total_lots += position.Volume();
               main_type = position.PositionType();
            }
         }
         
         // Abrir hedge na direção oposta
         if(main_type == POSITION_TYPE_BUY)
         {
            if(trade.Sell(total_lots, _Symbol, 0, 0, 0, "EMERGENCY HEDGE"))
            {
               hedge_active = true;
               Print("⚠️ HEDGE DE EMERGÊNCIA ATIVADO! Drawdown: ", drawdown_percent, "%");
               if(panel) panel.ShowNotification("HEDGE ATIVADO!", clrRed);
            }
         }
         else
         {
            if(trade.Buy(total_lots, _Symbol, 0, 0, 0, "EMERGENCY HEDGE"))
            {
               hedge_active = true;
               Print("⚠️ HEDGE DE EMERGÊNCIA ATIVADO! Drawdown: ", drawdown_percent, "%");
               if(panel) panel.ShowNotification("HEDGE ATIVADO!", clrRed);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Analisar virtual trades                                         |
//+------------------------------------------------------------------+
void AnalyzeVirtualTrades()
{
   if(virtual_trade_count == 0) return;
   
   int wins = 0;
   int total_closed = 0;
   
   for(int i = 0; i < virtual_trade_count; i++)
   {
      if(virtual_trades[i].closed)
      {
         total_closed++;
         if(virtual_trades[i].profit > 0) wins++;
      }
      else
      {
         // Verificar se virtual trade deve ser fechado
         double current_price = (virtual_trades[i].type == 0) ? 
                                SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double profit_points = (virtual_trades[i].type == 0) ?
                               (current_price - virtual_trades[i].entry_price) / _Point :
                               (virtual_trades[i].entry_price - current_price) / _Point;
         
         // Fechar virtual trade se atingir TP ou SL virtual
         if(MathAbs(profit_points) >= InpTakeProfit || MathAbs(profit_points) >= InpStopLoss)
         {
            virtual_trades[i].closed = true;
            virtual_trades[i].profit = profit_points;
            
            if(profit_points > 0) wins++;
            total_closed++;
         }
      }
   }
   
   // Calcular win rate
   if(total_closed > 0)
   {
      virtual_win_rate = (double)wins / total_closed * 100;
   }
}

//+------------------------------------------------------------------+
//| Adicionar virtual trade                                         |
//+------------------------------------------------------------------+
void AddVirtualTrade(int type, double price)
{
   if(virtual_trade_count >= ArraySize(virtual_trades))
   {
      ArrayResize(virtual_trades, virtual_trade_count + 10);
   }
   
   virtual_trades[virtual_trade_count].time = TimeCurrent();
   virtual_trades[virtual_trade_count].entry_price = price;
   virtual_trades[virtual_trade_count].type = (type == 1) ? 0 : 1; // 0=Buy, 1=Sell
   virtual_trades[virtual_trade_count].profit = 0;
   virtual_trades[virtual_trade_count].closed = false;
   
   virtual_trade_count++;
}

//+------------------------------------------------------------------+
//| Atualizar painel                                                |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel || panel == NULL) return;
   
   int total_pos = base.CountPositions();
   int buy_pos = base.CountPositions(POSITION_TYPE_BUY);
   int sell_pos = base.CountPositions(POSITION_TYPE_SELL);
   
   double open_profit = base.GetOpenProfit();
   double daily_profit = base.GetDailyProfit() + base.GetDailyLoss();
   double monthly_profit = base.GetMonthlyProfit() + base.GetMonthlyLoss();
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   
   panel.UpdateTradingData(
      total_pos, buy_pos, sell_pos,
      open_profit, daily_profit, monthly_profit,
      base.GetDailyTrades(), base.GetMonthlyTrades(),
      base.GetWinRate(), balance, equity, margin_level
   );
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Remover notificações temporárias
   if(panel != NULL)
   {
      panel.RemoveNotification();
   }
   EventKillTimer();
}
