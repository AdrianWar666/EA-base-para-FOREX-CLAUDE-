//+------------------------------------------------------------------+
//|                                              PrimeBotPanel.mqh   |
//|                              Copyright PrimeBot 2025             |
//|                     https://www.primebotportfolio.com.br/        |
//+------------------------------------------------------------------+
#property copyright "Copyright PrimeBot 2025"
#property link      "https://www.primebotportfolio.com.br/"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Sistema de Painel Visual PrimeBot                               |
//+------------------------------------------------------------------+
class CPrimeBotPanel
{
private:
   string            m_prefix;              // Prefixo para objetos
   string            m_ea_name;             // Nome do EA
   int               m_corner;              // Canto do painel
   int               m_x_offset;            // Deslocamento X
   int               m_y_offset;            // Deslocamento Y
   int               m_font_size;           // Tamanho da fonte
   string            m_font_name;           // Nome da fonte
   color             m_panel_color;         // Cor do painel
   color             m_header_color;        // Cor do cabeçalho
   color             m_text_color;          // Cor do texto
   color             m_profit_color;        // Cor para lucro
   color             m_loss_color;          // Cor para prejuízo
   
   // Dimensões do painel
   int               m_panel_width;
   int               m_panel_height;
   
public:
   //+------------------------------------------------------------------+
   //| Construtor                                                       |
   //+------------------------------------------------------------------+
   CPrimeBotPanel()
   {
      m_prefix = "PRIMEBOT_PANEL_";
      m_ea_name = "PRIMEBOT EA";
      m_corner = CORNER_LEFT_UPPER;
      m_x_offset = 20;
      m_y_offset = 20;
      m_font_size = 9;
      m_font_name = "Arial";
      m_panel_color = C'20,20,20';
      m_header_color = C'0,122,204';
      m_text_color = clrWhite;
      m_profit_color = clrLime;
      m_loss_color = clrRed;
      m_panel_width = 300;
      m_panel_height = 400;
   }
   
   //+------------------------------------------------------------------+
   //| Destrutor                                                        |
   //+------------------------------------------------------------------+
   ~CPrimeBotPanel()
   {
      DeletePanel();
   }
   
   //+------------------------------------------------------------------+
   //| Configurar painel                                               |
   //+------------------------------------------------------------------+
   void Configure(string ea_name, int corner = CORNER_LEFT_UPPER, int x = 20, int y = 20)
   {
      m_ea_name = ea_name;
      m_corner = corner;
      m_x_offset = x;
      m_y_offset = y;
   }
   
   //+------------------------------------------------------------------+
   //| Criar painel base                                               |
   //+------------------------------------------------------------------+
   void CreatePanel()
   {
      // Deletar painel existente
      DeletePanel();
      
      // Criar fundo do painel
      CreateRectangle(m_prefix + "BACKGROUND", 
                     m_x_offset, m_y_offset, 
                     m_panel_width, m_panel_height, 
                     m_panel_color, 1, true);
      
      // Criar cabeçalho
      CreateRectangle(m_prefix + "HEADER", 
                     m_x_offset, m_y_offset, 
                     m_panel_width, 35, 
                     m_header_color, 2, true);
      
      // Criar título
      CreateLabel(m_prefix + "TITLE", 
                 m_x_offset + 10, m_y_offset + 10, 
                 m_ea_name, 
                 clrWhite, 11, "Arial Bold");
      
      // Criar linha separadora
      CreateRectangle(m_prefix + "LINE1", 
                     m_x_offset, m_y_offset + 35, 
                     m_panel_width, 2, 
                     m_header_color, 2, true);
   }
   
   //+------------------------------------------------------------------+
   //| Atualizar painel com dados                                      |
   //+------------------------------------------------------------------+
   void UpdatePanel(string &data[][2])
   {
      int y_position = m_y_offset + 50;
      int line_height = 18;
      
      for(int i = 0; i < ArrayRange(data, 0); i++)
      {
         string label = data[i][0];
         string value = data[i][1];
         
         // Criar label
         CreateLabel(m_prefix + "LABEL_" + IntegerToString(i), 
                    m_x_offset + 10, y_position, 
                    label, m_text_color, m_font_size, m_font_name);
         
         // Determinar cor do valor
         color value_color = m_text_color;
         if(StringFind(value, "-") >= 0)
            value_color = m_loss_color;
         else if(StringFind(label, "Lucro") >= 0 || StringFind(label, "Profit") >= 0)
         {
            double val = StringToDouble(value);
            value_color = (val >= 0) ? m_profit_color : m_loss_color;
         }
         
         // Criar valor
         CreateLabel(m_prefix + "VALUE_" + IntegerToString(i), 
                    m_x_offset + m_panel_width - 10, y_position, 
                    value, value_color, m_font_size, m_font_name, 
                    ANCHOR_RIGHT_UPPER);
         
         y_position += line_height;
      }
      
      // Adicionar rodapé
      y_position = m_y_offset + m_panel_height - 30;
      CreateLabel(m_prefix + "FOOTER", 
                 m_x_offset + m_panel_width/2, y_position, 
                 "© PrimeBot 2025", 
                 C'100,100,100', 8, m_font_name, 
                 ANCHOR_CENTER);
      
      ChartRedraw();
   }
   
   //+------------------------------------------------------------------+
   //| Atualizar dados de trading                                      |
   //+------------------------------------------------------------------+
   void UpdateTradingData(int total_positions, int buy_positions, int sell_positions,
                         double open_profit, double daily_profit, double monthly_profit,
                         int daily_trades, int monthly_trades, double win_rate,
                         double balance, double equity, double margin_level)
   {
      string data[][2];
      ArrayResize(data, 15);
      
      // Informações da conta
      data[0][0] = "CONTA";
      data[0][1] = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
      
      data[1][0] = "Saldo";
      data[1][1] = DoubleToString(balance, 2);
      
      data[2][0] = "Equity";
      data[2][1] = DoubleToString(equity, 2);
      
      data[3][0] = "Margem Livre";
      data[3][1] = DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2);
      
      // Separador
      data[4][0] = "─────────────";
      data[4][1] = "─────────────";
      
      // Posições
      data[5][0] = "POSIÇÕES";
      data[5][1] = IntegerToString(total_positions);
      
      data[6][0] = "Compras";
      data[6][1] = IntegerToString(buy_positions);
      
      data[7][0] = "Vendas";
      data[7][1] = IntegerToString(sell_positions);
      
      data[8][0] = "Lucro Aberto";
      data[8][1] = DoubleToString(open_profit, 2);
      
      // Separador
      data[9][0] = "─────────────";
      data[9][1] = "─────────────";
      
      // Estatísticas
      data[10][0] = "HOJE";
      data[10][1] = "";
      
      data[11][0] = "Trades";
      data[11][1] = IntegerToString(daily_trades);
      
      data[12][0] = "Resultado";
      data[12][1] = DoubleToString(daily_profit, 2);
      
      data[13][0] = "MÊS";
      data[13][1] = "";
      
      data[14][0] = "Resultado";
      data[14][1] = DoubleToString(monthly_profit, 2);
      
      UpdatePanel(data);
   }
   
   //+------------------------------------------------------------------+
   //| Criar retângulo                                                 |
   //+------------------------------------------------------------------+
   void CreateRectangle(string name, int x, int y, int width, int height, 
                       color clr, int border_width = 0, bool fill = false)
   {
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      }
      
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, border_width);
      ObjectSetInteger(0, name, OBJPROP_BACK, fill);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   
   //+------------------------------------------------------------------+
   //| Criar label                                                     |
   //+------------------------------------------------------------------+
   void CreateLabel(string name, int x, int y, string text, color clr, 
                   int size = 9, string font = "Arial", 
                   ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
   {
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      }
      
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   
   //+------------------------------------------------------------------+
   //| Deletar painel                                                  |
   //+------------------------------------------------------------------+
   void DeletePanel()
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, m_prefix) >= 0)
         {
            ObjectDelete(0, name);
         }
      }
      ChartRedraw();
   }
   
   //+------------------------------------------------------------------+
   //| Mostrar notificação temporária                                  |
   //+------------------------------------------------------------------+
   void ShowNotification(string message, color msg_color = clrYellow, int duration = 3000)
   {
      string notification_name = m_prefix + "NOTIFICATION";
      
      // Criar notificação
      CreateRectangle(notification_name + "_BG", 
                     m_x_offset, m_y_offset + m_panel_height + 10, 
                     m_panel_width, 30, 
                     C'40,40,40', 2, true);
      
      CreateLabel(notification_name + "_TEXT", 
                 m_x_offset + m_panel_width/2, 
                 m_y_offset + m_panel_height + 25, 
                 message, msg_color, 10, "Arial Bold", 
                 ANCHOR_CENTER);
      
      ChartRedraw();
      
      // Agendar remoção
      EventSetTimer(duration / 1000);
   }
   
   //+------------------------------------------------------------------+
   //| Remover notificação                                             |
   //+------------------------------------------------------------------+
   void RemoveNotification()
   {
      ObjectDelete(0, m_prefix + "NOTIFICATION_BG");
      ObjectDelete(0, m_prefix + "NOTIFICATION_TEXT");
      ChartRedraw();
   }
};
