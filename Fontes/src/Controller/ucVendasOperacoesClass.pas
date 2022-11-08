unit ucVendasOperacoesClass;

interface

uses
  Vcl.Controls, Vcl.Forms, System.Classes, System.SysUtils, Vcl.DBCtrls,
  Winapi.Windows, Vcl.Dialogs,
  uiVendasOperacoes, uFrPedidoVenda, udmPrincipal, FireDAC.Stan.Param, Data.DB;

type
  TVendasOperacoes = class(TInterfacedObject,
    IVendasOperacoes)
  private
    FPedidosVenda: IVendasOperacoesPedidosVenda;

    function GetPedidosVenda: IVendasOperacoesPedidosVenda;
  public
    property PedidosVenda: IVendasOperacoesPedidosVenda read GetPedidosVenda;
  end;

  TVendasOperacoesFactory = class(TInterfacedObject,
    IVendasOperacoesFactory)
    function Construir: IVendasOperacoes;
  end;

  TVendasOperacoesPedidosVenda = class(TInterfacedObject,
    IVendasOperacoesPedidosVenda)
  private
    FFramePedidosVenda: TFrPedidoVenda;
    FAlterandoPedido: Boolean;

    procedure GravarPedido(Sender: TObject);
    procedure GravarItemPedido(Sender: TObject);
    procedure CancelarPedido(Sender: TObject);
    procedure ConsultarPedido(Sender: TObject);
    procedure ConsultarCliente(Sender: TObject; var Key: Char);
    procedure ConsultarProduto(Sender: TObject; var Key: Char);
    procedure CalcularValorTotalProduto(Sender: TObject; var Key: Char);
    function InformacoesValidasParaGravarPedido: Boolean;
    procedure CalcularValorItemInterno;
    procedure AtualizarDadosAoEncerrar(DataSet: TDataSet);
    procedure AtualizarStatusBotoes;
    procedure AoPressionarTeclaGrade(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    procedure Exibir(ControlContainer: TWinControl);
    procedure Ocultar;

    constructor Create;
    destructor Destroy; override;
  end;

  TVendasOperacoesPedidosVendaFactory = class(TInterfacedObject,
    IVendasOperacoesPedidosVendaFactory)
  public
    function Construir: IVendasOperacoesPedidosVenda;
  end;

implementation

{ TVendasOperacoes }

function TVendasOperacoes.GetPedidosVenda: IVendasOperacoesPedidosVenda;
var
  Factory: TVendasOperacoesPedidosVendaFactory;
begin
  if not Assigned(FPedidosVenda) then
  begin
    Factory := TVendasOperacoesPedidosVendaFactory.Create;
    try
      FPedidosVenda := Factory.Construir;
    finally
      Factory.DisposeOf;
    end;
  end;

  result := FPedidosVenda;
end;

procedure TVendasOperacoesPedidosVenda.GravarPedido(Sender: TObject);
begin
  if InformacoesValidasParaGravarPedido then
  begin
    if dtmPrincipal.cdsItensPedidos.state = dsInsert then
      dtmPrincipal.cdsItensPedidos.Cancel;

    if not(dtmPrincipal.cdsPedidos.State in dsEditModes) then
      dtmPrincipal.cdsPedidos.Edit;

    dtmPrincipal.cdsPedidos.FieldByName('Data_Emiss').AsDateTime := Now;
    dtmPrincipal.cdsPedidos.FieldByName('Valor_Total').AsFloat :=
      dtmPrincipal.cdsItensPedidosTotal_Pedido.Value;

    if dtmPrincipal.cdsItensPedidos.State in dsEditModes then
      dtmPrincipal.cdsItensPedidos.Post;

    if dtmPrincipal.cdsPedidos.State in dsEditModes then
      dtmPrincipal.cdsPedidos.Post;

    try
      dtmPrincipal.conPrincipal.StartTransaction;
      dtmPrincipal.cdsPedidos.ApplyUpdates(0);
      dtmPrincipal.cdsItensPedidos.ApplyUpdates(0);
      dtmPrincipal.conPrincipal.Commit;

      dtmPrincipal.cdsPedidos.Close;
      dtmPrincipal.cdsItensPedidos.Close;

      dtmPrincipal.cdsPedidos.ParamByName('Numero_Pedido').AsInteger := 0;
      dtmPrincipal.cdsItensPedidos.ParamByName('Numero_Pedido').AsInteger := 0;
      dtmPrincipal.cdsPedidos.Open;
      dtmPrincipal.cdsItensPedidos.Open;;

      FFramePedidosVenda.edtNomeCliente.Text := '';
      if FFramePedidosVenda.dbedtCodigoCliente.CanFocus then
        FFramePedidosVenda.dbedtCodigoCliente.SetFocus;

      FAlterandoPedido := False;
      Application.MessageBox('Pedido gravado com sucesso!', 'Informação', 0);
    except
      on E: Exception do
      begin
        Application.MessageBox(PWideChar('Erro ao gravar pedido: ' + E.Message), 'Erro', 0);
        dtmPrincipal.conPrincipal.Rollback;
      end;
    end;
  end;
end;

function TVendasOperacoesPedidosVenda.InformacoesValidasParaGravarPedido: Boolean;
begin
  result := False;
  if StrToIntDef(FFramePedidosVenda.dbedtCodigoCliente.Text, 0) = 0 then
  begin
    Application.MessageBox('Necessário informar o cliente no pedido!', 'Informação', 0);
    if FFramePedidosVenda.dbedtCodigoCliente.CanFocus then
      FFramePedidosVenda.dbedtCodigoCliente.SetFocus;
  end
  else
  if dtmPrincipal.cdsItensPedidos.IsEmpty then
  begin
    Application.MessageBox('Necessário incluir ao menos um produto no pedido!', 'Informação', 0);
    if FFramePedidosVenda.dbedtCodigoProduto.CanFocus then
      FFramePedidosVenda.dbedtCodigoProduto.SetFocus;
  end
  else
    result := True;
end;

procedure TVendasOperacoesPedidosVenda.AtualizarDadosAoEncerrar(DataSet: TDataSet);
begin
  AtualizarStatusBotoes;
end;

procedure TVendasOperacoesPedidosVenda.AtualizarStatusBotoes;
begin
  FFramePedidosVenda.btnConsultarPedido.Visible := dtmPrincipal.cdsPedidos.FieldByName('Codigo_Cliente').AsInteger = 0;
  FFramePedidosVenda.btnCancelarPedido.Visible := dtmPrincipal.cdsPedidos.FieldByName('Codigo_Cliente').AsInteger = 0;
end;

procedure TVendasOperacoesPedidosVenda.CalcularValorItemInterno;
begin
  if not (dtmPrincipal.cdsItensPedidos.State in dsEditModes) then
    dtmPrincipal.cdsItensPedidos.Edit;
  dtmPrincipal.cdsItensPedidos.FieldByName('Valor_Total').AsFloat :=
    (StrToFloatDef(FFramePedidosVenda.dbedtQuantidade.Text, 1) *
     StrToFloatDef(FFramePedidosVenda.dbedtValorUnitario.Text,0));
end;

procedure TVendasOperacoesPedidosVenda.CalcularValorTotalProduto(
  Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    CalcularValorItemInterno;

    if TDBEdit(Sender).Tag = 1 then
    begin
      if FFramePedidosVenda.dbedtValorUnitario.CanFocus then
         FFramePedidosVenda.dbedtValorUnitario.SetFocus;
    end
    else
      if FFramePedidosVenda.btnGravarItem.CanFocus then
        FFramePedidosVenda.btnGravarItem.SetFocus;
  end;
end;

procedure TVendasOperacoesPedidosVenda.CancelarPedido(Sender: TObject);
var
  NrPedido: Integer;
begin
  NrPedido:= StrToIntDef(InputBox('Cancelar Pedido', 'Número Pedido:', '0'),0);
  if NrPedido = 0 then
    Application.MessageBox('O número do pedido precisa ser informado!', 'Aviso', 0)
  else
  begin
    dtmPrincipal.qryExcluirItensPedido.ParamByName('Numero_Pedido').AsInteger := NrPedido;
    dtmPrincipal.qryExcluirItensPedido.ExecSQL;
    dtmPrincipal.qryExcluirPedido.ParamByName('Numero_Pedido').AsInteger := NrPedido;
    dtmPrincipal.qryExcluirPedido.ExecSQL;

    Application.MessageBox('O pedido foi cancelado com sucesso!', 'Aviso', 0);
  end;
end;

procedure TVendasOperacoesPedidosVenda.GravarItemPedido(Sender: TObject);
begin
  CalcularValorItemInterno;

  if dtmPrincipal.cdsPedidos.FieldByName('Numero_Pedido').AsInteger = 0 then
  begin
    dtmPrincipal.qryProximoPedido.Close;
    dtmPrincipal.qryProximoPedido.Open;

    if not (dtmPrincipal.cdsPedidos.State in dsEditModes) then
    dtmPrincipal.cdsPedidos.Edit;

    dtmPrincipal.cdsPedidos.FieldByName('Numero_Pedido').AsInteger :=
      dtmPrincipal.qryProximoPedido.FieldByName('Prox').AsInteger;
    dtmPrincipal.cdsItensPedidos.FieldByName('Numero_Pedido').AsInteger :=
      dtmPrincipal.qryProximoPedido.FieldByName('Prox').AsInteger;
  end;

  dtmPrincipal.cdsItensPedidos.FieldByName('Numero_Pedido').AsInteger :=
    dtmPrincipal.cdsPedidos.FieldByName('Numero_Pedido').AsInteger;

  if dtmPrincipal.cdsItensPedidos.State in dsEditModes then
    dtmPrincipal.cdsItensPedidos.Post;
  dtmPrincipal.cdsItensPedidos.Insert;

  if FFramePedidosVenda.dbedtCodigoProduto.CanFocus then
    FFramePedidosVenda.dbedtCodigoProduto.SetFocus;
end;

procedure TVendasOperacoesPedidosVenda.ConsultarCliente(Sender: TObject;
  var Key: Char);
begin
  if Key = #13 then
  begin
    dtmPrincipal.qryClientes.Close;

    dtmPrincipal.qryClientes.ParamByName('Codigo').AsString :=
      FFramePedidosVenda.dbedtCodigoCliente.Text;

    dtmPrincipal.qryClientes.Open;
    if not dtmPrincipal.qryClientes.IsEmpty then
    begin
      FFramePedidosVenda.edtNomeCliente.Text :=
        dtmPrincipal.qryClientes.FieldByName('Nome').AsString;

      if FFramePedidosVenda.dbedtCodigoProduto.CanFocus then
        FFramePedidosVenda.dbedtCodigoProduto.SetFocus;
    end
    else
    begin
      Application.MessageBox(PWideChar('Cliente "' +
        FFramePedidosVenda.dbedtCodigoCliente.Text + '" não cadastrado!'), '', 0);

      if FFramePedidosVenda.dbedtCodigoCliente.CanFocus then
        FFramePedidosVenda.dbedtCodigoCliente.SetFocus;
    end;

    AtualizarStatusBotoes;
  end;
end;

procedure TVendasOperacoesPedidosVenda.ConsultarPedido(Sender: TObject);
var
  NrPedido: Integer;
  Key: Char;
begin
  NrPedido:= StrToIntDef(InputBox('Carregar Pedido', 'Número Pedido:', '0'),0);
  if NrPedido = 0 then
    Application.MessageBox('O número do pedido precisa ser informado!', 'Aviso', 0)
  else
  begin
    dtmPrincipal.cdsPedidos.Close;
    dtmPrincipal.cdsItensPedidos.Close;
    dtmPrincipal.cdsPedidos.ParamByName('Numero_Pedido').AsInteger := NrPedido;
    dtmPrincipal.cdsPedidos.Open;

    dtmPrincipal.cdsItensPedidos.ParamByName('Numero_Pedido').AsInteger := NrPedido;
    dtmPrincipal.cdsItensPedidos.Open;

    if not dtmPrincipal.cdsPedidos.IsEmpty then
    begin
      AtualizarStatusBotoes;
      Key := #13;
      ConsultarCliente(nil, Key);
      FAlterandoPedido := True;
    end;
  end;
end;

procedure TVendasOperacoesPedidosVenda.ConsultarProduto(Sender: TObject;
  var Key: Char);
begin
  if Key = #13 then
  begin
    dtmPrincipal.qryProdutos.Close;

    dtmPrincipal.qryProdutos.ParamByName('Codigo').AsString :=
      FFramePedidosVenda.dbedtCodigoProduto.Text;

    dtmPrincipal.qryProdutos.Open;
    if not dtmPrincipal.qryProdutos.IsEmpty then
    begin
      dtmPrincipal.cdsItensPedidos.FieldByName('Codigo_Produto').AsInteger :=
        dtmPrincipal.qryProdutos.FieldByName('Codigo').AsInteger;

      dtmPrincipal.cdsItensPedidos.FieldByName('Valor_Unitario').AsFloat :=
        dtmPrincipal.qryProdutos.FieldByName('Preco_Venda').AsFloat;

      dtmPrincipal.cdsItensPedidos.FieldByName('Descricao').AsString :=
        dtmPrincipal.qryProdutos.FieldByName('Descricao').AsString;

      dtmPrincipal.cdsItensPedidos.FieldByName('Quantidade').AsFloat := 1;

      if FFramePedidosVenda.dbedtQuantidade.CanFocus then
        FFramePedidosVenda.dbedtQuantidade.SetFocus;
    end
    else
    begin
      Application.MessageBox(PWideChar('Cliente "' +
        FFramePedidosVenda.dbedtCodigoCliente.Text + '" não cadastrado!'), '', 0);

      if FFramePedidosVenda.dbedtCodigoCliente.CanFocus then
        FFramePedidosVenda.dbedtCodigoCliente.SetFocus;
    end;
  end;
end;

constructor TVendasOperacoesPedidosVenda.Create;
begin
  FFramePedidosVenda := TFrPedidoVenda.Create(Application);
end;

destructor TVendasOperacoesPedidosVenda.Destroy;
begin

  inherited;
end;

procedure TVendasOperacoesPedidosVenda.AoPressionarTeclaGrade(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_DELETE) and (not dtmPrincipal.cdsItensPedidos.IsEmpty) then
  begin
    if Application.MessageBox('Confirma exclusão do Item?', 'Pergunta', MB_YESNO) = ID_YES then
    begin
      dtmPrincipal.cdsItensPedidos.Delete;
      dtmPrincipal.cdsItensPedidos.Insert;
      if FFramePedidosVenda.dbedtCodigoProduto.CanFocus then
        FFramePedidosVenda.dbedtCodigoProduto.SetFocus;
    end;
  end;
end;

procedure TVendasOperacoesPedidosVenda.Exibir(ControlContainer: TWinControl);
begin
  FFramePedidosVenda.dsoPedidoVenda.DataSet := dtmPrincipal.cdsPedidos;
  FFramePedidosVenda.dsoPedidoVendaItens.DataSet := dtmPrincipal.cdsItensPedidos;

  dtmPrincipal.cdsPedidos.AfterClose := AtualizarDadosAoEncerrar;

  dtmPrincipal.cdsPedidos.Close;
  dtmPrincipal.cdsPedidos.Open;

  dtmPrincipal.cdsItensPedidos.Close;
  dtmPrincipal.cdsItensPedidos.ParamByName('NUMERO_PEDIDO').AsInteger :=
    dtmPrincipal.cdsPedidos.FieldByName('NUMERO_PEDIDO').AsInteger;
  dtmPrincipal.cdsItensPedidos.Open;

  FFramePedidosVenda.btnGravarPedido.OnClick := GravarPedido;
  FFramePedidosVenda.btnCancelarPedido.OnClick := CancelarPedido;
  FFramePedidosVenda.btnConsultarPedido.OnClick := ConsultarPedido;
  FFramePedidosVenda.btnGravarItem.OnClick := GravarItemPedido;

  FFramePedidosVenda.dbedtCodigoCliente.OnKeyPress := ConsultarCliente;
  FFramePedidosVenda.dbedtCodigoProduto.OnKeyPress := ConsultarProduto;
  FFramePedidosVenda.dbedtQuantidade.OnKeyPress := CalcularValorTotalProduto;
  FFramePedidosVenda.dbedtValorUnitario.OnKeyPress := CalcularValorTotalProduto;

  FFramePedidosVenda.dbgrdItensPedido.OnKeyDown := AoPressionarTeclaGrade;

  FFramePedidosVenda.Parent := ControlContainer;
  FFramePedidosVenda.Align := TAlign.alClient;
  FFramePedidosVenda.Visible := True;

  if FFramePedidosVenda.dbedtCodigoCliente.CanFocus then
    FFramePedidosVenda.dbedtCodigoCliente.SetFocus;

  AtualizarStatusBotoes;
end;

procedure TVendasOperacoesPedidosVenda.Ocultar;
begin
  FFramePedidosVenda.Visible := False;
end;

{ TVendasOperacoesPedidosVendaFactory }

function TVendasOperacoesPedidosVendaFactory.Construir: IVendasOperacoesPedidosVenda;
begin
  result := TVendasOperacoesPedidosVenda.Create;
end;

{ TVendasOperacoesFactory }

function TVendasOperacoesFactory.Construir: IVendasOperacoes;
begin
  result := TVendasOperacoes.Create;
end;

end.
