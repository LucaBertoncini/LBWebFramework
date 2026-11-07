unit uJSTabulator;

{$mode ObjFPC}{$H+}
{$modeswitch externalclass}

interface

uses
  SysUtils, JS, Web;

type
  TTabulator = class;

  TTabulatorMutatorProcedure = reference to function(value, data, _type, params, component: JSValue): JSValue;
  TTabulatorRowFormatter = reference to procedure(aRow: JSValue);
  TTabulatorCellFormatter = reference to function(cell, formatterParams, onRendered: JSValue): JSValue;
  TTabulatorCellClickEvent = reference to procedure(event, cell: JSValue);
  TTabulatorRowContextMenuEvent = reference to procedure(event, row: JSValue);
  TTabulatorRowDynamicMenuCreateEvent = reference to function(event, row: JSValue): TJSArray;
  TTabulatorHeaderColumnClickEvent = reference to function(e, column: JSValue): TJSArray;

  TTabulatorDropHandler = procedure(const SourceTable, TargetTable: TTabulator; const DraggedRow, TargetRow: TJSObject) of Object;


  TTabulatorDraggedItem = class(TObject)
    Source : TTabulator;
    Data : JSValue;
    TargetRow : TJSObject;
  end;

  { TTabulatorMenuItem }

  TTabulatorMenuItem = class(TObject)
    strict private
      FData : TJSObject;

    public
      constructor Create; reintroduce;

      procedure setLabel(const aText: String);
      procedure setCallback(aCallback: TTabulatorRowContextMenuEvent);

      property Data: TJSObject read FData;
  end;

  { TTabulatorHeader }

  TTabulatorHeader = class(TObject)
    strict private
      FHeader : TJSObject;

    public
      constructor Create; reintroduce;

      procedure setTitle(aValue: String);
      procedure setField(aValue: String);
      procedure setHorizontalAlign(aValueIdx: Integer);
      procedure setVerticalAlign(aValueIdx: Integer);
      procedure setData(aList: TJSArray);
      procedure setMutator(aFunction: TTabulatorMutatorProcedure);
      procedure setFormatter(aFunction: TTabulatorCellFormatter);
      procedure setSortable(aValue: Boolean; aSorterType: String = '');
      procedure setTimeEditor(aFormat: String);
      procedure setCSSClass(aCSSClass: String);
      procedure setAsImage(aHeight, aWidth: Integer);
      procedure setMaxWidth(aWidth: Integer);
      procedure setMinWidth(aWidth: Integer);
      procedure setWidthGrow(aValue: Integer);
      procedure setInputFilter(aValue: Boolean);
      procedure setImage(aCallback: JSValue);
      procedure setOnClick(aCallback: JSValue);

      procedure enableTextEditor();


      property Header: TJSObject read FHeader;

      const
        hozAlign : array [0 .. 2] of String = ('left', 'center', 'right');
        hozAlignLeft = Integer(0);
        hozAlignCenter = Integer(1);
        hozAlignRight = Integer(2);

        vertAlign : array [0 .. 2] of String = ('top', 'middle', 'bottom');
        vertAlignTop = Integer(0);
        vertAlignMiddle = Integer(1);
        vertAlignBottom = Integer(2);

        cSorter_Numeric = String('number');
        cSorter_String = String('string');
  end;


  { TTreeDataOptions }

  TTreeDataOptions = class(TObject)
    childrenField : String;
    ShowHeaders : Boolean;
    NeedCheckbox : Boolean;
    IdField : String;
    ValueField : String;
    DescriptionField : String;

    public
      constructor Create; reintroduce;
  end;

  TTreeDataDefaultHeaders = class(TObject)
    columnSelect : TTabulatorHeader;
    columnCode : TTabulatorHeader;
    columnValue : TTabulatorHeader;
  end;

  { TTabulator }

  TTabulator = class(TObject)
    strict private
      class var DragPayload: TTabulatorDraggedItem;

    strict private
      FOnCellClick : TTabulatorCellClickEvent;
      FOnDrop : TTabulatorDropHandler;

      FTreeDataOptions : TTreeDataOptions;
      FTabulatorIndex : Integer;

      FData : TJSArray;
      FOptions : TJSObject;
      FPanel : TJSHTMLDivElement;
      FTable : JSValue;

      //FTreeField: String;
      //FShowHeaders: Boolean;

      FEnableDrag : Boolean;
      FEnableDrop : Boolean;

      function CheckboxFormatter(cell, formatterParams, onRendered: JSValue): JSValue;
      function get_RowCount: Integer;
      function TreeFormatter(cell, formatterParams, onRendered: JSValue): JSValue;
      function ValueFormatter(cell, formatterParams, onRendered: JSValue): JSValue;

      procedure clearPanel();


    public
      constructor Create(aPanel: TJSHTMLDivElement); reintroduce;
      destructor Destroy; override;

      function UseTreeData(const aData: TJSArray; Options: TTreeDataOptions): TTreeDataDefaultHeaders;

      procedure addColumnHeader(aHeader: TTabulatorHeader);
      procedure setRowFormatter(aProcedure: TTabulatorRowFormatter);
      procedure setRowHeight(aHeight: Integer);
      procedure setData(aList: TJSArray);
      procedure setDataIndex(anIdx: String);
      procedure setColumnLayout(aValueIdx: Integer);

      procedure clearFixedRowMenu();
      procedure addFixedRowMenuItem(anItem: TTabulatorMenuItem);
      procedure setDynamicRowMenu(aCallback: TTabulatorRowDynamicMenuCreateEvent);

      procedure setLayout(aValue: Byte);

      procedure updateCellValue(aCell, aValue: JSValue);
      procedure deleteRowByCell(aCell: JSValue);


      function getValue(aCell: JSValue): JSValue;
      function getRow(aCell: JSValue): JSValue;
      function getRowByIndex(anIndex: Integer): JSValue;

      function getRowByUniqueIndex(anIndexValue: JSValue): JSValue;
      function getRowDataByCell(aCell: JSValue): TJSObject;
      function getRowDataByRow(aRow: JSValue): TJSObject;
      function getRowDataByRowIndex(aIdx: Integer): TJSObject;
      function getCellField(aCell: JSValue): JSValue;
      function getColumnIndex(aCell: JSValue): Integer;

      procedure refreshRowByUniqueIndex(anIndexValue: JSValue; aValue: JSValue = nil);
      procedure refreshRowByIndex(aRowIndex: Integer; const aField: String; aValue: JSValue);

      procedure updateValue(anIndex: JSValue; aField: String; aValue: JSValue);
      procedure updateRowValues(aRow: JSValue; anUpdatedObj: TJSObject);

      procedure addRow(aRow: TJSObject; onTop: Boolean);

      procedure Draw();
      procedure redraw();

      procedure disableHover();

      property RowCount: Integer read get_RowCount;

      property innerTable: JSValue read FTable;

      property EnableDrag: Boolean read FEnableDrag write FEnableDrag;
      property EnableDrop: Boolean read FEnableDrop write FEnableDrop;

      property OnCellClick: TTabulatorCellClickEvent write FOnCellClick;
      property OnDrop: TTabulatorDropHandler write FOnDrop;

      const
        layout : array [0 .. 3] of String = ('fitDataFill', 'fitDataStretch', 'fitDataTable', 'fitColumns');
        layout_FitToDataAnFill = Integer(0);
        layout_FitToDataAndStretchLastColumn = Integer(1);
        layout_FitTableAndColumsToData = Integer(2);
        layout_FitToWidth = Integer(3);

      published
        procedure ToggleExpand(rowId: JSValue);
        procedure HandleDropEvent(ev: JSValue);
        procedure loadDraggedRow(event: JSValue; aRowUniqueId: JSValue);
  end;

  procedure SortTree(data: TJSArray; const descrField, childField: String);


implementation

uses
  strutils;

var
  gv_RemoveHover : TJSHTMLElement = nil;
  gv_TabulatorIndex : Integer = 0;

{ TTabulatorMenuItem }

constructor TTabulatorMenuItem.Create;
begin
  inherited Create;
  FData := TJSObject.new;
end;

procedure TTabulatorMenuItem.setLabel(const aText: String);
begin
  FData.Properties['label'] := aText;
end;

procedure TTabulatorMenuItem.setCallback(aCallback: TTabulatorRowContextMenuEvent);
begin
  FData.Properties['action'] := aCallback;
end;

{ TTabulatorHeader }


constructor TTabulatorHeader.Create;
begin
  inherited Create;

  FHeader := TJSObject.new;
end;

procedure TTabulatorHeader.setTitle(aValue: String);
begin
  FHeader.Properties['title'] := aValue;
end;

procedure TTabulatorHeader.setField(aValue: String);
begin
  FHeader.Properties['field'] := aValue;
end;

procedure TTabulatorHeader.setHorizontalAlign(aValueIdx: Integer);
begin
  FHeader.Properties['hozAlign'] := hozAlign[aValueIdx];
end;

procedure TTabulatorHeader.setVerticalAlign(aValueIdx: Integer);
begin
  FHeader.Properties['vertAlign'] := vertAlign[aValueIdx];
end;

procedure TTabulatorHeader.setData(aList: TJSArray);
begin
  if hasValue(aList) then
    FHeader.Properties['data'] := aList
  else
    JSDelete(FHeader, 'data');
end;

procedure TTabulatorHeader.setMutator(aFunction: TTabulatorMutatorProcedure);
begin
  FHeader.Properties['mutator'] := aFunction;
end;

procedure TTabulatorHeader.setFormatter(aFunction: TTabulatorCellFormatter);
begin
  FHeader.Properties['formatter'] := aFunction;
end;

procedure TTabulatorHeader.setSortable(aValue: Boolean; aSorterType: String);
begin
  FHeader.Properties['headerSort'] := aValue;
end;

procedure TTabulatorHeader.setTimeEditor(aFormat: String);
var
  _Params : TJSObject;

begin
  FHeader.Properties['editor'] := 'time';
  _Params := TJSObject.new;
  _Params.Properties['format'] := aFormat;
  _Params.Properties['verticalNavigation'] := 'table';
  FHeader.Properties['editorParams'] := _Params;
end;

procedure TTabulatorHeader.setCSSClass(aCSSClass: String);
begin
  FHeader.Properties['cssClass'] := aCSSClass;
end;

procedure TTabulatorHeader.setAsImage(aHeight, aWidth: Integer);
var
  _Params : TJSObject;

begin
  FHeader.Properties['formatter'] := 'image';
  _Params := TJSObject.new;
  _Params.Properties['height'] := IntToStr(aHeight) + 'px';
  _Params.Properties['width'] := IntToStr(aWidth) + 'px';
  FHeader.Properties['formatterParams'] := _Params;
end;

procedure TTabulatorHeader.setMaxWidth(aWidth: Integer);
begin
  FHeader.Properties['maxWidth'] := aWidth;
end;

procedure TTabulatorHeader.setMinWidth(aWidth: Integer);
begin
  FHeader.Properties['minWidth'] := aWidth;
end;

procedure TTabulatorHeader.setWidthGrow(aValue: Integer);
begin
  FHeader.Properties['widthGrow'] := aValue;
end;

procedure TTabulatorHeader.setInputFilter(aValue: Boolean);
begin
  if aValue then
    FHeader.Properties['headerFilter'] := 'input'
  else
    FHeader.Properties['headerFilter'] := nil;
end;

procedure TTabulatorHeader.setImage(aCallback: JSValue);
begin
  if hasValue(aCallback) then
    FHeader.Properties['titleFormatter'] := aCallback
  else
    FHeader.Properties['titleFormatter'] := nil;
end;

procedure TTabulatorHeader.setOnClick(aCallback: JSValue);
begin
  if hasValue(aCallback) then
    FHeader.Properties['headerClick'] := aCallback
  else
    FHeader.Properties['headerClick'] := nil;
end;

procedure TTabulatorHeader.enableTextEditor;
begin
  FHeader.Properties['editor'] := 'input';
end;

{ TTreeDataOptions }

constructor TTreeDataOptions.Create;
begin
  inherited Create;

  childrenField := '_children';
  IdField := 'id';
  ValueField := 'value';
  DescriptionField := 'name';

  ShowHeaders   := False;
  NeedCheckbox  := False;
end;


procedure SortTree(data: TJSArray; const descrField, childField: String);

  function CompareByName(a, b: JSValue): NativeInt;
  var
    _A, _B: String;
  begin
    _A := LowerCase(String(TJSObject(a)[descrField]));
    _B := LowerCase(String(TJSObject(b)[descrField]));

    if _A < _B then
      Result := -1
    else if _A > _B then
      Result := 1
    else
      Result := 0;
  end;

var
  i: Integer;
  _node: TJSObject;
  _children: TJSArray;

begin
  if (data = nil) then Exit;

  if (data.length > 1) then
    data.sort(@CompareByName);

  for i := 0 to data.length - 1 do
  begin
    _node := TJSObject(data[i]);

    if _node.HasOwnProperty(childField) then
      _children := TJSArray(_node[childField])
    else
      _children := nil;

    if (_children <> nil) and (_children.length > 1) then
      SortTree(_children, descrField, childField);
  end;
end;

function FlattenTree(data: TJSArray; parentId: JSValue; level: Integer; TreeDataOptions: TTreeDataOptions): TJSArray;
var
  i, j: Integer;
  node, flat: TJSObject;
  resultArr, children: TJSArray;
begin
  resultArr := TJSArray.new;

  for i := 0 to data.length - 1 do
  begin
    node := TJSObject(data[i]);

    if ((not hasValue(node[TreeDataOptions.IdField])) or (node[TreeDataOptions.IdField] = 0)) then
      node[TreeDataOptions.IdField] := 'tmpId_' + IntToStr(Random(1000000));

    flat := TJSObject.new;
    flat['id'] := node[TreeDataOptions.IdField];

    flat['name'] := node[TreeDataOptions.DescriptionField];
    flat['level'] := level;
    flat['parent'] := parentId;
    flat['expanded'] := node['expanded'] = True;
    flat['hasChildren'] := node.HasOwnProperty(TreeDataOptions.childrenField);
    flat['__ref'] := node;

    resultArr.push(flat);

    if Boolean(flat['expanded']) and Boolean(flat['hasChildren']) then
    begin
      children := FlattenTree(TJSArray(node[TreeDataOptions.childrenField]), node[TreeDataOptions.IdField], level + 1, TreeDataOptions);
      for j := 0 to children.length - 1 do
        resultArr.push(children[j]);
    end;
  end;

  Result := resultArr;
end;

{ TTabulator }

function TTabulator.TreeFormatter(cell, formatterParams, onRendered: JSValue): JSValue;
var
  rowData, node: TJSObject;
  row : JSValue;
  indent: Integer; icon: String;

begin
  rowData := Self.getRowDataByCell(cell);
  row := Self.getRow(cell);
  node := TJSObject(rowData['__ref']);
  indent := Integer(rowData['level']) * 20;

  if FEnableDrop and Boolean(rowData['hasChildren']) then
  begin
    asm
      let el = row.getElement();
      let destRow = rowData;
      el.ondragover = function(ev) {
        ev.preventDefault();
        const payload = $mod.TTabulator.DragPayload;
        payload.TargetRow = destRow;
      };
      el.ondrop = this.HandleDropEvent.bind(this);
    end;
  end;

  {$IFDEF FontAwesome}
  if Boolean(rowData['hasChildren']) then
    icon := ifThen(Boolean(rowData['expanded']),
                   '<i class="fas fa-folder-open tree-node-icon"></i>',
                   '<i class="fas fa-folder tree-node-icon"></i>')
  else
    icon := '<span class="tree-leaf-icon"></span>';

    if FEnableDrag then
    begin
      Result := '<div style="padding-left:' + IntToStr(indent) + 'px;" ' +
                'draggable="true" ondragstart="window.__tabulators[''' + FPanel.id + '''].loadDraggedRow(event, ' + String(node[FTreeDataOptions.IdField]) + ')">' +
                '<span class="tree-icon" onclick="window.__tabulators[''' + FPanel.id + '''].ToggleExpand(''' + String(node[FTreeDataOptions.IdField]) + ''')">' +
                  icon +
                '</span> ' +
                String(node[FTreeDataOptions.DescriptionField]) +
              '</div>';
    end
    else begin
      Result := '<div style="padding-left:' + IntToStr(indent) + 'px;" draggable="' + IfThen(FEnableDrag, 'true', 'false') + '">' +
                '<span class="tree-icon" onclick="window.__tabulators[''' + FPanel.id + '''].ToggleExpand(''' + String(node[FTreeDataOptions.IdField]) + ''')">' +
                  icon +
                '</span> ' +
                String(node[FTreeDataOptions.DescriptionField]) +
              '</div>';
    end;
  {$ELSE}
  if hasValue(node) then
  begin
    if Boolean(rowData['hasChildren']) then
      icon := ifThen(Boolean(rowData['expanded']), '📂', '📁')
    else
      icon := '🏷️';

    Result := '<div style="padding-left:' + IntToStr(indent) + 'px; draggable="' + IfThen(FEnableDrag, 'true', 'false') + '">' +
                '<span class="tree-icon" onclick="window.__tabulators[''' + FPanel.id + '''].ToggleExpand(' + String(node[FTreeDataOptions.IdField]) + ')">' +
                  icon +
                '</span> ' + String(node[FTreeDataOptions.DescriptionField]) + '</div>';
  end;
 {$ENDIF}
end;


function TTabulator.ValueFormatter(cell, formatterParams, onRendered: JSValue): JSValue;
var
  row, node: TJSObject;
begin
  row := Self.getRowDataByCell(cell);
  node := TJSObject(row['__ref']);
  Result := node[FTreeDataOptions.ValueField];
end;

procedure TTabulator.clearPanel();
begin
  if hasValue(FTable) then
  begin
    asm
    this.FTable.destroy();
    end;
    FTable := nil;
  end;

  if hasValue(FPanel) then
    FPanel.innerHTML := '';
end;

procedure TTabulator.HandleDropEvent(ev: JSValue);
begin
  if Assigned(FOnDrop) then
  begin
    if hasValue(TTabulator.DragPayload) then
    begin
      if (TTabulator.DragPayload.Source <> nil) and hasValue(TTabulator.DragPayload.Data) then
      begin
        FOnDrop(TTabulator.DragPayload.Source, Self, TJSObject(TTabulator.DragPayload.Data), TTabulator.DragPayload.TargetRow);
      end;
    end;
  end;
end;

function TTabulator.CheckboxFormatter(cell, formatterParams, onRendered: JSValue): JSValue;
var
  row, node: TJSObject;
  checked: String;
begin
  row := Self.getRowDataByCell(cell);
  node := TJSObject(row['__ref']);
  if Boolean(node['selected']) then checked := 'checked' else checked := '';
  Result := '<input type="checkbox" ' + checked + ' onclick="event.stopPropagation(); this.__rowId=' + String(node[FTreeDataOptions.IdField]) + ';">';
end;


function TTabulator.get_RowCount: Integer;
begin
  asm
  Result = this.FTable.getDataCount();
  end;
end;

constructor TTabulator.Create(aPanel: TJSHTMLDivElement);
begin
  inherited Create;

  if not hasValue(gv_RemoveHover) then
  begin
    gv_RemoveHover := TJSHTMLElement(document.createElement('style'));
    gv_RemoveHover.innerHTML := '.data-tabulator-hover-disabled .tabulator-row:hover {' +
                                                                         'background-color: inherit !important;' +
                                                                         'cursor: default !important;}';

    document.head.appendChild(gv_RemoveHover);
  end;

  gv_TabulatorIndex += 1;
  FTabulatorIndex := gv_TabulatorIndex;
  FTreeDataOptions := nil;

  FPanel := aPanel;

  FData := nil;
  FTable := nil;

  FOptions := TJSObject.create(nil);
end;

destructor TTabulator.Destroy;
begin
  Self.clearPanel();

  asm
    if (window.__tabulators && window.__tabulators[this.FPanel.id]) {
      delete window.__tabulators[this.FPanel.id];
    }
  end;


  inherited Destroy;
end;

function TTabulator.UseTreeData(const aData: TJSArray; Options: TTreeDataOptions): TTreeDataDefaultHeaders;
begin
  Result := TTreeDataDefaultHeaders.Create;

  FData := aData;
  FTreeDataOptions := Options;

  FOptions['headerVisible'] := Options.ShowHeaders;
  FOptions['layout'] := 'fitColumns';

  SortTree(FData, FTreeDataOptions.DescriptionField, FTreeDataOptions.IdField);

  Self.setDataIndex('id'); // Options.IdField);

  if Options.NeedCheckbox then
  begin
    Result.columnSelect := TTabulatorHeader.Create;
    Result.columnSelect.setTitle('');
    Result.columnSelect.setField('selected');
    Result.columnSelect.setHorizontalAlign(TTabulatorHeader.hozAlignCenter);
    Result.columnSelect.setSortable(False);
    Result.columnSelect.setFormatter(@CheckboxFormatter);
    Self.addColumnHeader(Result.columnSelect);
  end;

  Result.columnCode := TTabulatorHeader.Create;
  Result.columnCode.setTitle(ifThen(FTreeDataOptions.ShowHeaders, 'Codice'));
  Result.columnCode.setField('name');
  Result.columnCode.setHorizontalAlign(TTabulatorHeader.hozAlignLeft);
  Result.columnCode.setSortable(False);
  Result.columnCode.setFormatter(@Self.TreeFormatter);
  Self.addColumnHeader(Result.columnCode);

  if FTreeDataOptions.ValueField <> '' then
  begin
    Result.columnValue := TTabulatorHeader.Create;
    Result.columnValue.setTitle(ifThen(FTreeDataOptions.ShowHeaders, 'Valore'));
    Result.columnValue.setField(FTreeDataOptions.ValueField);
    Result.columnValue.setHorizontalAlign(TTabulatorHeader.hozAlignRight);
    Result.columnValue.setSortable(False);
    Result.columnValue.setFormatter(@ValueFormatter);
    Result.columnValue.setCSSClass('value-column');
    Self.addColumnHeader(Result.columnValue);
  end;
end;

procedure TTabulator.ToggleExpand(rowId: JSValue);
var
  row, node: TJSObject;
  scrollPos: Integer;

begin
  if not hasValue(FTable) then Exit;

  scrollPos := 0;
  asm
    scrollPos = this.FTable.element.scrollTop;
  end;

  row := Self.getRowDataByRow(Self.getRowByUniqueIndex(rowId));
  if hasValue(row) then
  begin
    node := TJSObject(row['__ref']);
    node['expanded'] := not Boolean(row['expanded']);
  end;

  FOptions['data'] := FlattenTree(FData, nil, 0, FTreeDataOptions);

  asm
    this.FTable.setData(this.FOptions['data']).then(() => {
      this.FTable.element.scrollTop = scrollPos;
    });
  end;
end;


procedure TTabulator.addColumnHeader(aHeader: TTabulatorHeader);
var
  _Cols : TJSArray;

const
  cColums = 'columns';

begin
  if hasValue(aHeader) then
  begin
    _Cols := TJSArray(FOptions.Properties[cColums]);
    if not hasValue(_Cols) then
    begin
      _Cols := TJSArray.new;
      FOptions.Properties[cColums] := _Cols;
    end;

    _Cols.push(aHeader.Header);
  end;
end;

procedure TTabulator.setRowFormatter(aProcedure: TTabulatorRowFormatter);
begin
  FOptions.Properties['rowFormatter'] := aProcedure;
end;

procedure TTabulator.setRowHeight(aHeight: Integer);
begin
  FOptions.Properties['rowHeight'] := aHeight;
end;

procedure TTabulator.setData(aList: TJSArray);
begin
  FData := aList;
  if hasValue(FTable) then
  begin
    asm
    this.FTable.setData(this.FData);
    end;
  end;
end;

procedure TTabulator.setDataIndex(anIdx: String);
begin
  FOptions.Properties['index'] := anIdx;
end;

procedure TTabulator.setColumnLayout(aValueIdx: Integer);
begin
  FOptions.Properties['layout'] := layout[aValueIdx];
end;

procedure TTabulator.clearFixedRowMenu;
var
  _Item : JSValue;

begin
  _Item := FOptions.Properties['rowContextMenu'];
  if hasValue(_Item) then
    _Item := TJSArray.new();
end;

procedure TTabulator.addFixedRowMenuItem(anItem: TTabulatorMenuItem);
var
  _Menu : TJSArray;
  _Item : JSValue;

begin
  _Item := FOptions.Properties['rowContextMenu'];
  if (_Item is TJSArray) then
    _Menu := TJSArray(_Item)
  else begin
    _Menu := TJSArray.new;
    FOptions.Properties['rowContextMenu'] := _Menu;
  end;
  _Menu.push(anItem.Data);
end;

procedure TTabulator.setDynamicRowMenu(aCallback: TTabulatorRowDynamicMenuCreateEvent);
begin
  FOptions.Properties['rowContextMenu'] := aCallback;
end;

procedure TTabulator.setLayout(aValue: Byte);
begin
  FOptions['layout'] := layout[aValue]; // 'fitColumns';
end;

procedure TTabulator.updateCellValue(aCell, aValue: JSValue);
begin
  asm
  aCell.setValue(aValue, true);
  end;
end;

procedure TTabulator.deleteRowByCell(aCell: JSValue);
begin
  asm
  aCell.getRow().delete();
  end;
end;

function TTabulator.getValue(aCell: JSValue): JSValue;
begin
  Result := nil;
  asm
  Result = aCell.getValue();
  end;
end;

function TTabulator.getRow(aCell: JSValue): JSValue;
begin
  Result := nil;
  asm
  Result = aCell.getRow();
  end;
end;

function TTabulator.getRowByIndex(anIndex: Integer): JSValue;
begin
  asm
  Result = this.FTable.getRows()[anIndex];
  end;
end;

function TTabulator.getRowByUniqueIndex(anIndexValue: JSValue): JSValue;
begin
  Result := nil;
  asm
  Result = this.FTable.getRow(anIndexValue);
  end;
end;

function TTabulator.getRowDataByCell(aCell: JSValue): TJSObject;
begin
  Result := nil;
  asm
  Result = aCell.getData();
  end;
end;

function TTabulator.getRowDataByRow(aRow: JSValue): TJSObject;
begin
  Result := nil;
  asm
  Result = aRow.getData();
  end;
end;

function TTabulator.getRowDataByRowIndex(aIdx: Integer): TJSObject;
var
  _Row : TJSObject;

begin
  Result := nil;
  _Row := nil;

  asm
  _Row = this.FTable.getRows()[aIdx];
  Result = _Row.getData();
  end;
end;

function TTabulator.getCellField(aCell: JSValue): JSValue;
begin
  Result := '';
  asm
  Result = aCell.getField();
  end;
end;

function TTabulator.getColumnIndex(aCell: JSValue): Integer;
begin
  Result := 0;
  asm
  var _Column = aCell.getColumn();
  Result = this.FTable.getColumns().indexOf(_Column);
  end;
end;

procedure TTabulator.refreshRowByUniqueIndex(anIndexValue: JSValue; aValue: JSValue);
begin
  if not hasValue(FTable) then Exit;

  asm
  const row = this.FTable.getRow(anIndexValue);
  if (row) {
    // Forza aggiornamento visivo passando il valore effettivo da __ref
    const data = row.getData();
    if ((typeof aValue !== 'undefined') && (aValue !== null)) { data.__ref.value = aValue; }
    if (data && data.__ref && "value" in data.__ref) {
      row.update({ value: data.__ref.value });
    }
  }
  end;
end;

procedure TTabulator.refreshRowByIndex(aRowIndex: Integer; const aField: String; aValue: JSValue);
var
  _Row : JSValue;

begin
  if not hasValue(FTable) then Exit;

  asm
  const row = this.FTable.getRows()[aIdx];
  if (row) {
    // Forza aggiornamento visivo passando aggiuornado il valore
    const data = row.getData();
    if (data) and (aField in data) {
      let _Obj = {};
      _Obj[aField] = aValue;

      row.update(_Obj);
    }
  }
  end;
end;

procedure TTabulator.updateValue(anIndex: JSValue; aField: String; aValue: JSValue);
var
  _row : JSValue;
  _rowData : TJSObject;

begin
  _row := Self.getRowByUniqueIndex(anIndex);
  if hasValue(_row) then
  begin
    _rowData := Self.getRowDataByRow(_row);

    if FTreeDataOptions <> nil then
      TJSObject(_rowData.Properties['__ref']).Properties[aField] := aValue
    else
      _rowData.Properties[aField] := aValue;

    asm
    _row.update(_rowData);
    end;
  end;
end;

procedure TTabulator.updateRowValues(aRow: JSValue; anUpdatedObj: TJSObject);
begin
  asm aRow.update(anUpdatedObj); end;
end;

procedure TTabulator.addRow(aRow: TJSObject; onTop: Boolean);
var
  _Obj : TJSObject;

begin
  _Obj := aRow;
  if not hasValue(_Obj) then
    _Obj := TJSObject.new;

  asm
  this.FTable.addRow(_Obj, onTop);
  end;
end;

procedure TTabulator.Draw();
begin
  Self.clearPanel();

  if FPanel.id = '' then
    FPanel.id := 'tabulator_' + IntToStr(FTabulatorIndex);

  FOptions.Properties['height'] := FPanel.ClientHeight;
  //FOptions['layout'] := 'fitColumns';

  if hasValue(FData) then
  begin
    if FTreeDataOptions <> nil then
      FOptions['data'] := FlattenTree(FData, nil, 0, FTreeDataOptions)
    else
      FOptions['data'] := FData;
  end;

//  if not hasValue(TTabulator.RegisteredTabulators) then
//    TTabulator.RegisteredTabulators := TJSMap.new();

//  TTabulator.RegisteredTabulators.&set(FPanel.id, Self);

  asm
    if (!window.__tabulators) window.__tabulators = {};
    window.__tabulators[this.FPanel.id] = this;

    this.FTable = new Tabulator('#' + this.FPanel.id, this.FOptions);
    if (this.FOnCellClick) { this.FTable.on("cellClick", this.FOnCellClick); }
  end;
end;

procedure TTabulator.redraw();
begin
  if hasValue(FTable) then asm this.FTable.redraw(true) end;
end;

procedure TTabulator.disableHover();
begin
  FPanel.classList.add('data-tabulator-hover-disabled');
end;

procedure TTabulator.loadDraggedRow(event: JSValue; aRowUniqueId: JSValue);
var
  _row : JSValue;

begin

  if not hasValue(TTabulator.DragPayload) then
    TTabulator.DragPayload := TTabulatorDraggedItem.Create;

  _row := Self.getRowByUniqueIndex(aRowUniqueId);
  TTabulator.DragPayload.Source := Self;
  TTabulator.DragPayload.Data := Self.getRowDataByRow(_row);
  asm event.dataTransfer.setData("text/plain", "drag"); end;
end;


end.

