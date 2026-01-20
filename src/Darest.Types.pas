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
unit Darest.Types;

interface

uses
	System.IOUtils, System.Classes, System.NetEncoding, System.SysUtils,
	FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async, FireDAC.Stan.Param,
	FireDAC.DApt, FireDAC.Stan.Intf, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef;

const
	SERVICE_PORT = 9000;
	APP_NAME = 'Darest - Database Auto REST';
	MAX_PERM_COLS = 5;
	STATIC_HTML_FOLDER = 'swagger';
	CONFIG_DB = 'Darest.db';

type
	TCRUDPerm = record
		Visible: Boolean;
		Select: Boolean;
		Insert: Boolean;
		Update: Boolean;
		Delete: Boolean;
	end;

	TTablePermission = record
		Name: string;
		IsView: Boolean;
		Perm: TCRUDPerm;
	end;

type
	TConfiguration = record
		ServiceHost: String;
		ServicePort: integer;
		UIHeight: integer;
		UIWidth: integer;
		ColTableNameWidth: integer;
		DatabaseParams: string;
		ApplicationPath: string;
		URI: string;
		TablePermissions: string;
		AutoConnect: Boolean;
		LoginPrompt: Boolean;
		function ServerConfigured: boolean;
	end;

var
	FConfiguration: TConfiguration;

procedure LoadConfiguration;
procedure SaveConfiguration;
procedure ApplySavedParamsToConnection(ADestConn: TFDConnection; const EncodedParams: string);
procedure Base64ToParams(const ABase64: string; AParams: TStrings);
function ParamsToBase64(AParams: TStrings): string;

implementation

function GetConfigConnection: TFDConnection;
begin
	var sql:=
	'''
	CREATE TABLE IF NOT EXISTS Active (uri TEXT);
	CREATE TABLE IF NOT EXISTS Configuration (
		ID INTEGER PRIMARY KEY AUTOINCREMENT,
		URI Text, TablePermissions Text,
		ServicePort INTEGER,
		ServiceHost TEXT,
		UIHeight INTEGER DEFAULT (520),
		UIWidth INTEGER DEFAULT (720),
		ColTableNameWidth INTEGER DEFAULT (200),
		DatabaseParams TEXT,
		AutoConnect INTEGER CHECK (AutoConnect IN (0, 1)),
		LoginPrompt INTEGER CHECK (LoginPrompt IN (0, 1)))
	''';
	Result := TFDConnection.Create(nil);
	Result.LoginPrompt := False;
	Result.DriverName := 'SQLite';
	Result.Params.Values['Database'] := CONFIG_DB;
	Result.Params.Values['OpenMode'] := 'CreateUTF8';
	Result.Connected := True;
	Result.ExecSQL(sql);
end;

// --- Serialization Helpers for TStrings (params) ---
function ParamsToBase64(AParams: TStrings): string;
var
	ms: TMemoryStream;
	bytes: TBytes;
begin
	Result := '';
	ms := TMemoryStream.Create;
	try
		AParams.SaveToStream(ms);
		if ms.Size = 0 then
			Exit;
		ms.Position := 0;
		SetLength(bytes, ms.Size);
		ms.ReadBuffer(bytes[0], ms.Size);
		Result := TNetEncoding.Base64.EncodeBytesToString(bytes);
	finally
		ms.Free;
	end;
end;

procedure Base64ToParams(const ABase64: string; AParams: TStrings);
var
	bytes: TBytes;
	ms: TMemoryStream;
begin
	AParams.Clear;
	if ABase64 = '' then
		Exit;
	bytes := TNetEncoding.Base64.DecodeStringToBytes(ABase64);
	ms := TMemoryStream.Create;
	try
		if Length(bytes) > 0 then
			ms.WriteBuffer(bytes[0], Length(bytes));
		ms.Position := 0;
		AParams.LoadFromStream(ms);
	finally
		ms.Free;
	end;
end;

// --- Apply decoded params to TFDConnection  ---
procedure ApplySavedParamsToConnection(ADestConn: TFDConnection; const EncodedParams: string);
begin
	ADestConn.Close;
	ADestConn.Params.Clear;
	if EncodedParams <> '' then
		Base64ToParams(EncodedParams, ADestConn.Params);
end;

procedure SetSwaggerHostPort(const AHost: string; const APort: integer);
var
	swagger: TArray<String>;
	line: string;
	i: integer;
begin
	var
	swaggerFolder := TPath.Combine(FConfiguration.ApplicationPath, STATIC_HTML_FOLDER);
	if not DirectoryExists(swaggerFolder) then
		ForceDirectories(swaggerFolder);
	var
	swaggerInit := TPath.Combine(swaggerFolder, 'swagger-initializer.js');

	if fileExists(swaggerInit) then
	begin
		swagger := TFile.ReadAllLines(swaggerInit, TEncoding.UTF8);
		i := 0;
		for line in swagger do
		begin
			if line.Contains('url:') then
				swagger[i] := Format(#9'url: "%s:%d/swagger",', [AHost, APort]);
			inc(i);
		end;
		TFile.WriteAllLines(swaggerInit, swagger, TEncoding.UTF8)
	end;

end;

// ---
procedure SaveConfiguration;
var
	Conn: TFDConnection;
	Qry: TFDQuery;
begin
	Conn := GetConfigConnection;
	try
		Qry := TFDQuery.Create(nil);
		try
			Qry.Connection := Conn;
			Qry.Open('select ID from Configuration where URI=:uri', [FConfiguration.URI]);
			var
				Id: integer;
			Id := Qry.FieldByName('ID').AsInteger;

			Qry.Close;
			if Id = 0 then
			begin
				Qry.SQL.Text :=
					 'INSERT INTO Configuration (ServiceHost, ServicePort, UIWidth, UIHeight, ColTableNameWidth, DatabaseParams, URI, TablePermissions, AutoConnect, LoginPrompt) '
					 + 'VALUES (:ServiceHost, :ServicePort, :UIWidth, :UIHeight, :ColTableNameWidth, :DatabaseParams, :URI, :TablePermissions, :AutoConnect, :LoginPrompt);';
			end
			else
			begin
				Qry.SQL.Text := 'UPDATE Configuration set ServiceHost=:ServiceHost, ServicePort=:ServicePort, UIWidth=:UIWidth, UIHeight=:UIHeight, ' +
					 'ColTableNameWidth=:ColTableNameWidth, DatabaseParams=:DatabaseParams, TablePermissions=:TablePermissions, URI=:URI, AutoConnect=:AutoConnect, LoginPrompt=:LoginPrompt '
					 + 'WHERE ID=:ID;';
				Qry.ParamByName('ID').AsInteger := Id;
			end;
			Qry.ParamByName('ServiceHost').AsString := FConfiguration.ServiceHost;
			Qry.ParamByName('ServicePort').AsInteger := FConfiguration.ServicePort;
			Qry.ParamByName('UIWidth').AsInteger := FConfiguration.UIWidth;
			Qry.ParamByName('UIHeight').AsInteger := FConfiguration.UIHeight;
			Qry.ParamByName('ColTableNameWidth').AsInteger := FConfiguration.ColTableNameWidth;
			Qry.ParamByName('URI').AsString := FConfiguration.URI;
			Qry.ParamByName('DatabaseParams').AsString := FConfiguration.DatabaseParams; // should be encoded
			Qry.ParamByName('TablePermissions').AsString := FConfiguration.TablePermissions;
			Qry.ParamByName('AutoConnect').AsInteger := Ord(FConfiguration.AutoConnect);
			Qry.ParamByName('LoginPrompt').AsInteger := Ord(FConfiguration.LoginPrompt);
			Qry.ExecSQL;

			if FConfiguration.URI <> '' then
			begin
				Qry.Close;
				Qry.ExecSQL('INSERT or REPLACE into active (uri) values (:URI);', [FConfiguration.URI]);
			end;

			SetSwaggerHostPort(FConfiguration.ServiceHost, FConfiguration.ServicePort);

		finally
			Qry.Free;
		end;
	finally
		Conn.Free;
	end;
end;

// ---
procedure LoadConfiguration;
var
	Conn: TFDConnection;
	Qry: TFDQuery;
begin
	Conn := GetConfigConnection;
	try
		Qry := TFDQuery.Create(nil);
		try
			Qry.Connection := Conn;

			var
				URI: string;
			Qry.Open('select URI from active limit 1');
			URI := Qry.FieldByName('URI').AsString;

			Qry.SQL.Text := 'SELECT ServiceHost, ServicePort, UIHeight, UIWidth, ColTableNameWidth, ' +
				 'DatabaseParams, TablePermissions, URI, AutoConnect, LoginPrompt FROM Configuration where URI=:URI';
			Qry.ParamByName('URI').AsString := URI;
			Qry.Open;

			if not Qry.IsEmpty then
			begin
        FConfiguration.ServiceHost := Qry.FieldByName('ServiceHost').AsString;
				FConfiguration.ServicePort := Qry.FieldByName('ServicePort').AsInteger;
				FConfiguration.DatabaseParams := Qry.FieldByName('DatabaseParams').AsString; // Base64
				FConfiguration.UIHeight := Qry.FieldByName('UIHeight').AsInteger;
				FConfiguration.UIWidth := Qry.FieldByName('UIWidth').AsInteger;
				FConfiguration.ColTableNameWidth := Qry.FieldByName('ColTableNameWidth').AsInteger;
				FConfiguration.TablePermissions := Qry.FieldByName('TablePermissions').AsString;
				FConfiguration.AutoConnect := (Qry.FieldByName('AutoConnect').AsInteger = 1);
				FConfiguration.LoginPrompt := (Qry.FieldByName('LoginPrompt').AsInteger = 1);
				FConfiguration.URI := Qry.FieldByName('URI').AsString;
				if FConfiguration.ColTableNameWidth < 200 then
					FConfiguration.ColTableNameWidth := 200;
			end
			else
			begin
				// Defaults
        FConfiguration.ServiceHost := 'http://localhost';
				FConfiguration.ServicePort := SERVICE_PORT;
				FConfiguration.UIHeight := 520;
				FConfiguration.UIWidth := 720;
				FConfiguration.ColTableNameWidth := 200;
				FConfiguration.DatabaseParams := '';
				FConfiguration.TablePermissions := '';
				FConfiguration.URI := '';
				FConfiguration.AutoConnect := False;
				FConfiguration.LoginPrompt := False;
				SaveConfiguration();
			end;
		finally
			Qry.Free;
		end;
	finally
		Conn.Free;
	end;
end;

{ TConfiguration }

function TConfiguration.ServerConfigured: boolean;
var
	Conn: TFDConnection;
	Qry: TFDQuery;
begin
	Result := false;
	Conn := GetConfigConnection;
	Qry := TFDQuery.Create(nil);
	try
		Qry.Connection := Conn;
		Qry.Open('select URI from active limit 1');
		Result := not Qry.IsEmpty;
	finally
		Qry.Free;
		Conn.Free;
	end;
end;

end.
