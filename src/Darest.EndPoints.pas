(*
================================================================================
  Darest - Auto-generated REST API from your database schema

  Copyright (c) 2026 Magno Lima - Magnum Labs
  Website: www.magnumlabs.com.br

  Licensed under the MIT License

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
================================================================================
*)
unit Darest.EndPoints;

interface

uses
	System.Classes, System.SysUtils, System.StrUtils, System.IOUtils,
	FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
	FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
	FireDAC.Phys, FireDAC.Comp.Client, FireDAC.Comp.DataSet,
	FireDAC.DApt, Data.DB, System.Generics.Collections, Horse, Horse.Commons,
	System.JSON, Darest.Types, Darest.Logic, Darest.Helpers;

type
	TRouteClass = class
		Path: string;
		Name: string;
	end;

procedure RegisterDBEndpoints(ADataBaseConnector: TDataBaseConnector);
function GetContentType(const AFile: string): string;

implementation

function PhysicalColumnExists(AConnection: TFDConnection;
	 const TableName, Col: string): Boolean;
var
	Q: TFDQuery;
begin
	Result := False;
	Q := TFDQuery.Create(nil);
	try
		Q.Connection := AConnection;
		Q.SQL.Text := Format('SELECT * FROM %s WHERE 1=0', [TableName]);
		Q.Open;
		Result := Q.FindField(Col) <> nil;
	finally
		Q.Free;
	end;
end;

function TrySelectPseudoColumn(AConnection: TFDConnection;
	 const TableName, Col: string): Boolean;
var
	Q: TFDQuery;
begin
	Result := False;
	Q := TFDQuery.Create(nil);
	try
		Q.Connection := AConnection;
		Q.SQL.Text := Format('SELECT %s FROM %s WHERE 1=0', [Col, TableName]);
		try
			Q.Open;
			Result := True;
		except
			Result := False;
		end;
	finally
		Q.Free;
	end;
end;

procedure EnsurePKOrRowID(AConnection: TFDConnection; const TableName: string;
	 out KeyField: string);
var
	L: TStringList;
	MI: TFDMetaInfoQuery;
	drv: string;
begin

	KeyField := '';

	// Oficial API FireDAC: PKs names
	// Note: correct signature GetKeyFieldNames(ACatalog, ASchema, ATable, APattern, AList)
	L := TStringList.Create;
	try
		AConnection.GetKeyFieldNames('', '', TableName, '', L);
		if L.Count > 0 then
		begin
			KeyField := L[0];
			// If the primary key is a composite key, can adapt it to return the entire list.
			Exit;
		end;
	finally
		L.Free;
	end;

	// Fallback: uses TFDMetaInfoQuery as mkPrimaryKeyFields (column 'COLUMN_NAME')
	MI := TFDMetaInfoQuery.Create(nil);
	try
		MI.Connection := AConnection;
		MI.MetaInfoKind := mkPrimaryKeyFields;
		MI.BaseObjectName := TableName;
		MI.Open;
		if not MI.IsEmpty then
		begin
			// mkPrimaryKeyFields has column COLUMN_NAME (doc FireDAC)
			KeyField := MI.FieldByName('COLUMN_NAME').AsString;
			Exit;
		end;
	finally
		MI.Free;
	end;

	// Heuristics for PK common names...
	if PhysicalColumnExists(AConnection, TableName, 'ID') then
	begin
		KeyField := 'ID';
		Exit;
	end;
	if PhysicalColumnExists(AConnection, TableName, 'Id') then
	begin
		KeyField := 'Id';
		Exit;
	end;
	if PhysicalColumnExists(AConnection, TableName, TableName + 'ID') then
	begin
		KeyField := TableName + 'ID';
		Exit;
	end;
	if PhysicalColumnExists(AConnection, TableName, LowerCase(TableName) + 'id')
	then
	begin
		KeyField := LowerCase(TableName) + 'id';
		Exit;
	end;

	// Pseudocolumns / row identifiers per driver
	drv := UpperCase(AConnection.DriverName);
	if (drv = 'ORA') and TrySelectPseudoColumn(AConnection, TableName, 'ROWID')
	then
		KeyField := 'ROWID'
	else if ((drv = 'FB') or (drv = 'IB')) and TrySelectPseudoColumn(AConnection,
		 TableName, 'RDB$DB_KEY') then
		KeyField := 'RDB$DB_KEY'
	else if (drv = 'PG') and TrySelectPseudoColumn(AConnection, TableName, 'OID')
	then
		KeyField := 'OID'
	else if (drv = 'SQLITE') and (TrySelectPseudoColumn(AConnection, TableName,
		 'ROWID') or TrySelectPseudoColumn(AConnection, TableName, '_rowid_')) then
		KeyField := 'ROWID';

	if KeyField = '' then
		raise Exception.CreateFmt
			 ('We were unable to identify a key/rowid for %s. Define a PK or enter it manually..',
			 [TableName]);
end;

// *** ------------------------------------------ *** \\
// Endpoints
// *** ------------------------------------------ *** \\

function GetContentType(const AFile: string): string;
var
	LExt: string;
begin
	LExt := LowerCase(ExtractFileExt(AFile));
	if LExt = '.html' then
		Exit('text/html; charset=utf-8');
	if LExt = '.js' then
		Exit('application/javascript; charset=utf-8');
	if LExt = '.css' then
		Exit('text/css; charset=utf-8');
	if LExt = '.json' then
		Exit('application/json; charset=utf-8');
	if LExt = '.png' then
		Exit('image/png');
	if LExt = '.gif' then
		Exit('image/gif');
	if (LExt = '.jpg') or (LExt = '.jpeg') then
		Exit('image/jpeg');
	if LExt = '.svg' then
		Exit('image/svg+xml');
	if LExt = '.ico' then
		Exit('image/x-icon');
	if (LExt = '.woff') or (LExt = '.woff2') then
		Exit('font/woff');
	if LExt = '.ttf' then
		Exit('font/ttf');
	if LExt = '.eot' then
		Exit('application/vnd.ms-fontobject');
	Result := 'application/octet-stream';
end;

procedure RegisterDBEndpoints(ADataBaseConnector: TDataBaseConnector);
begin
	// Endpoint retuns Swagger's JSON (OpenAPI Specification)
	THorse.Get('/swagger',
		procedure(Req: THorseRequest; Res: THorseResponse)
		begin
			Res.ContentType('application/json; charset=UTF-8');
			// CORS headers
			Res.AddHeader('Access-Control-Allow-Origin', '*');
			Res.AddHeader('Access-Control-Allow-Methods',
				 'GET, POST, PUT, DELETE, OPTIONS');
			Res.AddHeader('Access-Control-Allow-Headers',
				 'Content-Type, Authorization');
			Res.Send(ADataBaseConnector.GetSwaggerJSON);
		end);

	THorse.Get('/',
		procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
		var
			FilePath, HTML: string;
		begin
			FilePath := TPath.Combine(TPath.Combine(ExtractFilePath(ParamStr(0)),
				 STATIC_HTML_FOLDER), 'index.html');
			if TFile.Exists(FilePath) then
			begin
				HTML := TFile.ReadAllText(FilePath, TEncoding.UTF8);
				Res.ContentType('text/html; charset=utf-8').Send(HTML);
			end
			else
				Res.Status(404).Send('Página não encontrada');
		end);

	// ***************************************** \\
	THorse.Get('/schema',
		procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
		var
			Pair: TPair<string, TTablePermission>;
			Arr: TJSONArray;
			Obj, Perm: TJSONObject;
		begin
			Res.ContentType('application/json; charset=UTF-8');
			Arr := TJSONArray.Create;
			try
				for Pair in ADataBaseConnector.SchemePermissions do
				begin

					if not Pair.Value.Perm.Visible then
						Continue;
					Obj := TJSONObject.Create;
					Obj.AddPair('name', Pair.Value.Name);
					Obj.AddPair('isView', TJSONBool.Create(Pair.Value.IsView));

					Perm := TJSONObject.Create;
					Perm.AddPair('visible', TJSONBool.Create(Pair.Value.Perm.Visible));
					Perm.AddPair('select', TJSONBool.Create(Pair.Value.Perm.Select));
					Perm.AddPair('insert', TJSONBool.Create(Pair.Value.Perm.Insert));
					Perm.AddPair('update', TJSONBool.Create(Pair.Value.Perm.Update));
					Perm.AddPair('delete', TJSONBool.Create(Pair.Value.Perm.Delete));

					Obj.AddPair('permissions', Perm);

					Arr.AddElement(Obj);
				end;

				Res.Send(Arr.ToJSON);
			except
				Arr.Free;
				raise;
			end;
		end);

	// GET /data/:table
	THorse.Get('/data/:table',
		procedure(Req: THorseRequest; Res: THorseResponse)
		var
			TableName, SQL, KeyField: string;
			Limit, Offset: Integer;
			Q: TFDQuery;
			JA: TJSONArray;
		begin
			Res.ContentType('application/json; charset=UTF-8');

			TableName := Req.Params['table'];
			Limit := StrToIntDef(Req.Query['limit'], 50);
			Offset := StrToIntDef(Req.Query['offset'], 0);

			EnsurePKOrRowID(ADataBaseConnector.DatabaseConnnection, TableName,
				 KeyField);

			Q := TFDQuery.Create(nil);
			try
				Q.Connection := ADataBaseConnector.DatabaseConnnection;
				SQL := BuildPagedSelect('SELECT * FROM ' + TableName,
					 ADataBaseConnector.DatabaseConnnection.DriverName,
					 'ORDER BY ' + KeyField);
				Q.SQL.Text := SQL;

				if SQL.Contains(':_limit') then
					Q.ParamByName('_limit').AsInteger := Limit;
				if SQL.Contains(':_offset') then
					Q.ParamByName('_offset').AsInteger := Offset;
				if SQL.Contains(':_start') then
					Q.ParamByName('_start').AsInteger := Offset + 1;
				if SQL.Contains(':_end') then
					Q.ParamByName('_end').AsInteger := Offset + Limit;

				Q.Open;

				JA := TJSONArray.Create;
				try
					while not Q.Eof do
					begin
						JA.AddElement(RowToJSONObject(Q));
						Q.Next;
					end;
					Res.Send(JA.ToJSON);
				finally
					JA.Free;
				end;
			finally
				Q.Free;
			end;
		end);

	// GET /data/:table/:id
	THorse.Get('/data/:table/:id',
		procedure(Req: THorseRequest; Res: THorseResponse)
		var
			TableName, KeyField, SQL: string;
			Q: TFDQuery;
		begin
			Res.ContentType('application/json; charset=UTF-8');

			TableName := Req.Params['table'];
			EnsurePKOrRowID(ADataBaseConnector.DatabaseConnnection, TableName,
				 KeyField);

			Q := TFDQuery.Create(nil);
			try
				Q.Connection := ADataBaseConnector.DatabaseConnnection;
				SQL := Format('SELECT * FROM %s WHERE %s = :id', [TableName, KeyField]);
				Q.SQL.Text := SQL;
				Q.ParamByName('id').AsString := Req.Params['id'];
				Q.Open;

				if not Q.Eof then
					Res.Send(RowToJSONObject(Q).ToJSON)
				else
					Res.Status(404).Send('Not found');
			finally
				Q.Free;
			end;
		end);

	// POST /data/:table
	THorse.Post('/data/:table',
		procedure(Req: THorseRequest; Res: THorseResponse)
		var
			TableName, SQL, Fields, Values: string;
			Q: TFDQuery;
			JsonObj: TJSONObject;
			I: Integer;
			FieldNames, ParamNames: TStringList;
		begin
			Res.ContentType('application/json; charset=UTF-8');
			TableName := Req.Params['table'];
			JsonObj := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
			if JsonObj = nil then
			begin
				Res.Status(400).Send('Invalid JSON');
				Exit;
			end;

			FieldNames := TStringList.Create;
			ParamNames := TStringList.Create;
			Q := TFDQuery.Create(nil);
			try
				Q.Connection := ADataBaseConnector.DatabaseConnnection;

				for I := 0 to JsonObj.Count - 1 do
				begin
					FieldNames.Add(JsonObj.Pairs[I].JsonString.Value);
					ParamNames.Add(':' + JsonObj.Pairs[I].JsonString.Value);
				end;

				SQL := Format('INSERT INTO %s (%s) VALUES (%s)',
					 [TableName, FieldNames.CommaText, ParamNames.CommaText]);
				Q.SQL.Text := SQL;

				for I := 0 to JsonObj.Count - 1 do
					Q.ParamByName(JsonObj.Pairs[I].JsonString.Value).Value :=
						 JsonObj.Pairs[I].JsonValue.Value;

				Q.ExecSQL;

				Res.Status(201).Send('Inserted');
			finally
				FieldNames.Free;
				ParamNames.Free;
				JsonObj.Free;
				Q.Free;
			end;
		end);

	// PUT /data/:table/:id
	THorse.Put('/data/:table/:id',
		procedure(Req: THorseRequest; Res: THorseResponse)
		var
			TableName, KeyField, SQL, SetClause: string;
			Q: TFDQuery;
			JsonObj: TJSONObject;
			I: Integer;
		begin
			Res.ContentType('application/json; charset=UTF-8');
			TableName := Req.Params['table'];
			EnsurePKOrRowID(ADataBaseConnector.DatabaseConnnection, TableName,
				 KeyField);

			JsonObj := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
			if JsonObj = nil then
			begin
				Res.Status(400).Send('Invalid JSON');
				Exit;
			end;

			Q := TFDQuery.Create(nil);
			try
				Q.Connection := ADataBaseConnector.DatabaseConnnection;
				SetClause := '';
				for I := 0 to JsonObj.Count - 1 do
				begin
					if I > 0 then
						SetClause := SetClause + ', ';
					SetClause := SetClause + JsonObj.Pairs[I].JsonString.Value + ' = :' +
						 JsonObj.Pairs[I].JsonString.Value;
				end;

				SQL := Format('UPDATE %s SET %s WHERE %s = :id', [TableName, SetClause,
					 KeyField]);
				Q.SQL.Text := SQL;

				for I := 0 to JsonObj.Count - 1 do
					Q.ParamByName(JsonObj.Pairs[I].JsonString.Value).Value :=
						 JsonObj.Pairs[I].JsonValue.Value;
				Q.ParamByName('id').Value := Req.Params['id'];

				Q.ExecSQL;
				Res.Status(200).Send('Updated');
			finally
				JsonObj.Free;
				Q.Free;
			end;
		end);

	// DELETE /data/:table/:id
	THorse.Delete('/data/:table/:id',
		procedure(Req: THorseRequest; Res: THorseResponse)
		var
			TableName, KeyField, SQL: string;
			Q: TFDQuery;
		begin
			Res.ContentType('application/json; charset=UTF-8');
			TableName := Req.Params['table'];
			EnsurePKOrRowID(ADataBaseConnector.DatabaseConnnection, TableName,
				 KeyField);

			Q := TFDQuery.Create(nil);
			try
				Q.Connection := ADataBaseConnector.DatabaseConnnection;
				SQL := Format('DELETE FROM %s WHERE %s = :id', [TableName, KeyField]);
				Q.SQL.Text := SQL;
				Q.ParamByName('id').Value := Req.Params['id'];
				Q.ExecSQL;
				Res.Status(200).Send('Deleted');
			finally
				Q.Free;
			end;
		end);
end;

end.
