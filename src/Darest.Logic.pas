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
unit Darest.Logic;

interface

uses
	System.SysUtils, System.Classes, System.Generics.Collections,
	System.JSON, System.StrUtils, System.IOUtils, System.SyncObjs,
	FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
	FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
	FireDAC.Phys, FireDAC.Comp.Client, FireDAC.Comp.DataSet,
	Darest.Types, FireDAC.DApt, Data.DB;

type
	TDataBaseConnector = class
	private
		FDatabaseConnection: TFDConnection;
		FLoginPrompt: Boolean;
		FDriverID: string;
		FPerms: TDictionary<string, TTablePermission>;
		FPort: Integer;
		FIsRunning: Boolean;
		FConfigurationFile: string;
		procedure RequireConnected;
		function NormalKey(const S: string): string;
		function TableExists(const AName: string): Boolean;
	public
		constructor Create;
		destructor Destroy; override;
		procedure ConfigureConnection(const ALoginPrompt: Boolean);
		procedure Connect;
		procedure Disconnect;
		procedure ReloadDatabaseSchema;
		function ListObjects: TArray<TTablePermission>;
		procedure SetPermissions(const AList: TArray<TTablePermission>);
		procedure StartRESTServer(APort: Integer);
		procedure StopRESTServer;
		property IsRunning: Boolean read FIsRunning write FIsRunning;
		function GetSwaggerJSON: string;
		function SetTablesPermissions(const AJson: string; out APermissions: TArray<TTablePermission>;
			out APromptLogin: Boolean): Boolean;
		property Connection: TFDConnection read FDatabaseConnection;
		property ConfigurationFile: string read FConfigurationFile write FConfigurationFile;
		property SchemePermissions: TDictionary<string, TTablePermission> read FPerms write FPerms;
		property LoginPrompt: Boolean read FLoginPrompt write FLoginPrompt;
		property DatabaseConnnection: TFDConnection read FDatabaseConnection write FDatabaseConnection;
		procedure ConnectDatabase(APermissions: TArray<TTablePermission>);
	end;

implementation

uses
	System.NetEncoding, System.Types, Horse.Jhonson,
	Horse, Horse.JWT, Horse.CORS, Horse.Commons,
	Darest.EndPoints;

var
	GActiveReq: Integer = 0;

procedure InstallActiveCounter;
begin
	THorse.Use(
		procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
		begin
			TInterlocked.Increment(GActiveReq);
			try
				Next();
			finally
				TInterlocked.Decrement(GActiveReq);
			end;
		end
	);
end;

procedure StopHorseGracefully;
var
  i: Integer;
begin
  if not THorse.IsRunning then Exit;

  THorse.StopListen;

	// wait up 2s (200 * 10ms) per running request
	for i := 1 to 200 do
	begin
		if TInterlocked.CompareExchange(GActiveReq, 0, 0) = 0 then
			Break;
		Sleep(10);
	end;
end;

{ TDBConnector }
constructor TDataBaseConnector.Create;
begin
	inherited Create;
	FDatabaseConnection := TFDConnection.Create(nil);
	FPerms := TDictionary<string, TTablePermission>.Create;
end;

destructor TDataBaseConnector.Destroy;
begin
	StopRESTServer;
	FPerms.Free;
	FDatabaseConnection.Free;
	inherited;
end;

procedure TDataBaseConnector.ConfigureConnection(const ALoginPrompt: Boolean);
begin

	if FileExists(FConfiguration.ApplicationPath + Self.ConfigurationFile) then
		FDatabaseConnection.Params.LoadFromFile(FConfiguration.ApplicationPath + Self.ConfigurationFile);

	FDatabaseConnection.LoginPrompt := ALoginPrompt;
end;

procedure TDataBaseConnector.Connect;
begin
	if not FDatabaseConnection.Connected then
		FDatabaseConnection.Connected := True;
end;

procedure TDataBaseConnector.ConnectDatabase(APermissions: TArray<TTablePermission>);
var
	LLogin: Boolean;
begin
	if Self.FDatabaseConnection.Params.Text.IsEmpty then
		Exit;

	SetTablesPermissions(FConfiguration.TablePermissions, APermissions, LLogin);

	Self.LoginPrompt := LLogin;

	Self.ConfigureConnection(Self.LoginPrompt);
	try
		FDatabaseConnection.Connected := True;
	except
		raise;
  end;
	Self.ReloadDatabaseSchema();

end;

procedure TDataBaseConnector.Disconnect;
begin
	if FDatabaseConnection.Connected then
		FDatabaseConnection.Connected := False;
end;

procedure TDataBaseConnector.RequireConnected;
begin
	if not FDatabaseConnection.Connected then
		raise Exception.Create('Connection was not established.');
end;

function TDataBaseConnector.NormalKey(const S: string): string;
begin
	Result := LowerCase(Trim(S));
end;

function TDataBaseConnector.TableExists(const AName: string): Boolean;
var
	L: TStringList;
begin
	RequireConnected;
	L := TStringList.Create;
	try
		FDatabaseConnection.GetTableNames('', '', '', L, [osMy], [tkTable, tkView]);
		Result := L.IndexOf(AName) >= 0;
	finally
		L.Free;
	end;
end;

procedure TDataBaseConnector.ReloadDatabaseSchema();
var
	Tbs: TStringList;
	i: Integer;
	tp: TTablePermission;
	Name: string;
begin
	RequireConnected;
	FPerms.Clear;
	Tbs := TStringList.Create;
	try
		FDatabaseConnection.GetTableNames('', '', '', Tbs, [osMy], [tkTable, tkView]);
		for i := 0 to Tbs.Count - 1 do
		begin
			Name := Tbs[i];
			if Name.IsEmpty then
				Continue;
			tp.Name := Name;
			tp.IsView := False;
			tp.Perm.Select := False;
			tp.Perm.Insert := False;
			tp.Perm.Update := False;
			tp.Perm.Delete := False;
			FPerms.AddOrSetValue(NormalKey(Name), tp);
		end;
	finally
		Tbs.Free;
	end;
end;

function TDataBaseConnector.ListObjects: TArray<TTablePermission>;
var
	arr: TArray<TTablePermission>;
	v: TTablePermission;
	idx: Integer;
begin
	SetLength(arr, FPerms.Count);
	idx := 0;
	for v in FPerms.Values do
	begin
		arr[idx] := v;
		Inc(idx);
	end;
	Result := arr;
end;

procedure TDataBaseConnector.SetPermissions(const AList: TArray<TTablePermission>);
var
	tp: TTablePermission;
begin
	for tp in AList do
		if FPerms.ContainsKey(NormalKey(tp.Name)) then
			FPerms[NormalKey(tp.Name)] := tp;
	// Self.SchemePermissions.:= FPermissions;
end;

// =====================
// REST (Horse) endpoints
// =====================
function StaticFileMiddleware(const AStaticPath: string): THorseCallback;
begin
	Result := procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
		var
			RequestPath, FilePath, RelativePath: string;
		begin
			RequestPath := Req.RawWebRequest.PathInfo;

			// Check if it's a request for a static file (not just '/').
			if (RequestPath <> '/') and (RequestPath <> '') then
			begin
				// Remove a barra inicial se existir
				RelativePath := RequestPath;
				if RelativePath.StartsWith('/') then
					RelativePath := RelativePath.Substring(1);

				// Build file full path
				FilePath := TPath.Combine(AStaticPath, RelativePath);
				if TFile.Exists(FilePath) then
				begin
					try
						// Send file with correct content-type
						Res.ContentType(GetContentType(FilePath));
						Res.SendFile(FilePath);
						Exit;
					except
						raise;
						{on E: Exception do
						begin
							// Log if need
							// WriteLn('Error sending file: ' + E.Message);
						end;}
					end;
				end;
			end;

			Next;
		end;
end;

procedure TDataBaseConnector.StartRESTServer(APort: Integer);
var
	pathHome: string;
begin
	try
		FDatabaseConnection.Open;
		// Configure static file path
		pathHome := TPath.Combine(ExtractFilePath(ParamStr(0)), STATIC_HTML_FOLDER);

		// Adds middleware for static files
		THorse.Use(StaticFileMiddleware(pathHome));

		(*
			// Enable CORS for all routes
			THorse.Use(CORS);
			// ou com configurações específicas:
			THorse.Use(CORS(THorseCORSConfig.New
			.AllowedOrigin('*')  // Permite qualquer origem (cuidado em produção!)
			.AllowedMethods('GET,POST,PUT,DELETE')
			.AllowedHeaders('*')
			));
		*)

		// Main page (root)
		THorse.Get('/',
			procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
			var
				FilePath, HTML: string;
			begin
				FilePath := TPath.Combine(pathHome, 'index.html');
				if TFile.Exists(FilePath) then
				begin
					HTML := TFile.ReadAllText(FilePath, TEncoding.UTF8);
					Res.ContentType('text/html; charset=utf-8').Send(HTML);
				end
				else
					Res.Status(404).Send('Page not found.');
			end);

		THorse.Listen(APort);
		FIsRunning := True;
	except
		FIsRunning := False;
	end;
end;

procedure TDataBaseConnector.StopRESTServer;
begin
	if THorse.IsRunning then
	begin
		StopHorseGracefully;
		//THorse.StopListen;
		FPort := 0;
	end;
	FIsRunning := THorse.IsRunning;
end;

function TDataBaseConnector.GetSwaggerJSON: string;
var
	J, Paths, PathObj, MethodObj, ParamSchema: TJSONObject;
	ParamsArr: TJSONArray;
	tp: TTablePermission;
	pathBase: string;
begin
	J := TJSONObject.Create;
	try

		J.AddPair('openapi', '3.0.0');
		J.AddPair('info', TJSONObject.Create.AddPair('title', APP_NAME).AddPair('version', '1.0.0').AddPair('description', 'Database API: ' + Self.DatabaseConnnection.Params.Values
			 ['database']));

		Paths := TJSONObject.Create;
		FPerms := Self.SchemePermissions;

		for tp in FPerms.Values do
		begin
			pathBase := '/data/' + tp.Name;

			if not tp.Perm.Visible then
				Continue;

			PathObj := TJSONObject.Create;

			// GET /data/:table (com paginação)
			if tp.Perm.Select then
			begin
				ParamsArr := TJSONArray.Create;

				// ?limit
				ParamSchema := TJSONObject.Create;
				ParamSchema.AddPair('type', 'integer');
				ParamsArr.AddElement(TJSONObject.Create.AddPair('name', 'limit').AddPair('in', 'query').AddPair('schema',
					 ParamSchema));

				// ?offset
				ParamSchema := TJSONObject.Create;
				ParamSchema.AddPair('type', 'integer');
				ParamsArr.AddElement(TJSONObject.Create.AddPair('name', 'offset').AddPair('in', 'query').AddPair('schema',
					 ParamSchema));

				MethodObj := TJSONObject.Create;
				MethodObj.AddPair('summary', 'List ' + tp.Name);
				MethodObj.AddPair('parameters', ParamsArr);
				MethodObj.AddPair('responses', TJSONObject.Create.AddPair('200',
					 TJSONObject.Create.AddPair('description', 'OK')));
				PathObj.AddPair('get', MethodObj);
			end;

			// POST /data/:table
			if tp.Perm.Insert then
			begin
				MethodObj := TJSONObject.Create;
				MethodObj.AddPair('summary', 'Insert into ' + tp.Name);
				MethodObj.AddPair('responses', TJSONObject.Create.AddPair('200',
					 TJSONObject.Create.AddPair('description', 'OK')));
				PathObj.AddPair('post', MethodObj);
			end;

				if PathObj.Count > 0 then
				Paths.AddPair(pathBase, PathObj);

				if tp.Perm.Update or tp.Perm.Delete then
			begin
				PathObj := TJSONObject.Create;

				if tp.Perm.Update then
				begin
					// We create a separated ParamsArr for UPDATE
					ParamsArr := TJSONArray.Create;
					ParamsArr.AddElement(TJSONObject.Create.AddPair('name', 'id').AddPair('in', 'path').AddPair('required',
						 TJSONBool.Create(True)).AddPair('schema', TJSONObject.Create.AddPair('type', 'string')));

					MethodObj := TJSONObject.Create;
					MethodObj.AddPair('summary', 'Update ' + tp.Name);
					MethodObj.AddPair('parameters', ParamsArr);
					MethodObj.AddPair('responses', TJSONObject.Create.AddPair('200',
						 TJSONObject.Create.AddPair('description', 'OK')));
					PathObj.AddPair('put', MethodObj);
				end;

				if tp.Perm.Delete then
				begin
					// We create a separated ParamsArr for DELETE
					ParamsArr := TJSONArray.Create;
					ParamsArr.AddElement(TJSONObject.Create.AddPair('name', 'id').AddPair('in', 'path').AddPair('required',
						 TJSONBool.Create(True)).AddPair('schema', TJSONObject.Create.AddPair('type', 'string')));

					MethodObj := TJSONObject.Create;
					MethodObj.AddPair('summary', 'Delete from ' + tp.Name);
					MethodObj.AddPair('parameters', ParamsArr);
					MethodObj.AddPair('responses', TJSONObject.Create.AddPair('200',
						 TJSONObject.Create.AddPair('description', 'OK')));
					PathObj.AddPair('delete', MethodObj);
				end;

				// Adding PathObj for {id} if has methods
				if PathObj.Count > 0 then
					Paths.AddPair(pathBase + '/{id}', PathObj);
			end;
		end;

		J.AddPair('paths', Paths);
		Result := J.ToJSON;
	finally
		J.Free;
	end;
end;

function TDataBaseConnector.SetTablesPermissions(const AJson: string;
out APermissions: TArray<TTablePermission>; out APromptLogin: Boolean): Boolean;
var
	i: Integer;
	RootObject: TJSONObject;
	PermissionsArray: TJSONArray;
	JSONValue: TJSONValue;
begin
	Result := False;

	if AJson.IsEmpty then
		Exit;

	SetLength(APermissions, 0);
	APromptLogin := False;

	try
		JSONValue := TJSONObject.ParseJSONValue(AJson);
		try

			if not(JSONValue is TJSONObject) then
				raise Exception.Create('Invalid JSON format: root is not an object');
			RootObject := JSONValue as TJSONObject;
			RootObject.TryGetValue<Boolean>('PromptLogin', APromptLogin);

			if RootObject.TryGetValue<TJSONArray>('Permissions', PermissionsArray) then
			begin
				SetLength(APermissions, PermissionsArray.Count);

				for i := 0 to PermissionsArray.Count - 1 do
				begin
					var
					JSONObject := PermissionsArray.Items[i] as TJSONObject;
					if not Assigned(JSONObject) then
						Continue;
					APermissions[i].Name := JSONObject.GetValue<string>('Name', '');
					var
					PermObj := JSONObject.GetValue<TJSONObject>('Perm');
					if Assigned(PermObj) then
					begin
						APermissions[i].Perm.Visible := PermObj.GetValue<Boolean>('Visible', False);
						APermissions[i].Perm.Select := PermObj.GetValue<Boolean>('Select', False);
						APermissions[i].Perm.Insert := PermObj.GetValue<Boolean>('Insert', False);
						APermissions[i].Perm.Update := PermObj.GetValue<Boolean>('Update', False);
						APermissions[i].Perm.Delete := PermObj.GetValue<Boolean>('Delete', False);
					end;
				end;
			end;
		finally
			JSONValue.Free;
		end;
		Result := True;
	except
		on E: Exception do
			raise;
	end;
end;

end.
