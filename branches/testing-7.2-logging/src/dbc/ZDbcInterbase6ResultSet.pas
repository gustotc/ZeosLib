{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         Interbase Database Connectivity Classes         }
{                                                         }
{        Originally written by Sergey Merkuriev           }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcInterbase6ResultSet;

interface

{$I ZDbc.inc}

uses
  {$IFDEF WITH_TOBJECTLIST_INLINE}System.Types, System.Contnrs{$ELSE}Types{$ENDIF},
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF}
  {$IF defined (WITH_INLINE) and defined(MSWINDOWS) and not defined(WITH_UNICODEFROMLOCALECHARS)}Windows, {$IFEND}
  ZDbcIntfs, ZDbcResultSet, ZDbcInterbase6, ZPlainFirebirdInterbaseConstants,
  ZPlainFirebirdDriver, ZCompatibility, ZDbcResultSetMetadata, ZMessages,
  ZDbcInterbase6Utils;

type

  {** Implements Interbase ResultSet. }
  TZInterbase6ResultSet = class(TZAbstractResultSet)
  private
    FCachedBlob: boolean;
    FFetchStat: Integer;
    FCursorName: AnsiString;
    FStmtHandle: TISC_STMT_HANDLE;
    FSqlData: IZResultSQLDA;
    FIBConnection: IZInterbase6Connection;
    FCodePageArray: TWordDynArray;
  protected
    procedure Open; override;
    function GetFieldValue(ColumnIndex: Integer): Variant;
    function InternalGetString(ColumnIndex: Integer): RawByteString; override;
  public
    constructor Create(Statement: IZStatement; SQL: string;
      var StatementHandle: TISC_STMT_HANDLE; CursorName: AnsiString;
      SqlData: IZResultSQLDA; CachedBlob: boolean);
    destructor Destroy; override;

    procedure Close; override;

    function GetCursorName: AnsiString; override;

    function IsNull(ColumnIndex: Integer): Boolean; override;
    function GetAnsiRec(ColumnIndex: Integer): TZAnsiRec; override;
    function GetPAnsiChar(ColumnIndex: Integer): PAnsiChar; override;
    function GetString(ColumnIndex: Integer): String; override;
    function GetUnicodeString(ColumnIndex: Integer): ZWideString; override;
    function GetBoolean(ColumnIndex: Integer): Boolean; override;
    function GetByte(ColumnIndex: Integer): Byte; override;
    function GetShort(ColumnIndex: Integer): SmallInt; override;
    function GetInt(ColumnIndex: Integer): Integer; override;
    function GetLong(ColumnIndex: Integer): Int64; override;
    function GetFloat(ColumnIndex: Integer): Single; override;
    function GetDouble(ColumnIndex: Integer): Double; override;
    function GetBigDecimal(ColumnIndex: Integer): Extended; override;
    function GetBytes(ColumnIndex: Integer): TByteDynArray; override;
    function GetDate(ColumnIndex: Integer): TDateTime; override;
    function GetTime(ColumnIndex: Integer): TDateTime; override;
    function GetTimestamp(ColumnIndex: Integer): TDateTime; override;
    function GetBlob(ColumnIndex: Integer): IZBlob; override;

    function MoveAbsolute(Row: Integer): Boolean; override;
    function Next: Boolean; override;
  end;

  {** Implements external blob wrapper object for Intebase/Firbird. }
  TZInterbase6UnCachedBlob = Class(TZAbstractUnCachedBlob)
  private
    FBlobId: TISC_QUAD;
    FDBHandle: PISC_DB_HANDLE;
    FTrHandle: PISC_TR_HANDLE;
    FPlainDriver: IZInterbasePlainDriver;
    FConSettings: PZConSettings;
  protected
    procedure ReadLob; override;
  public
    constructor Create(const DBHandle: PISC_DB_HANDLE;
      const TrHandle: PISC_TR_HANDLE; const PlainDriver: IZInterbasePlainDriver;
      var BlobId: TISC_QUAD; Const ConSettings: PZConSettings);
  end;

  TZInterbase6UnCachedClob = Class(TZAbstractUnCachedClob)
  private
    FBlobId: TISC_QUAD;
    FDBHandle: PISC_DB_HANDLE;
    FTrHandle: PISC_TR_HANDLE;
    FPlainDriver: IZInterbasePlainDriver;
  protected
    procedure ReadLob; override;
  public
    constructor Create(const DBHandle: PISC_DB_HANDLE;
      const TrHandle: PISC_TR_HANDLE; const PlainDriver: IZInterbasePlainDriver;
      var BlobId: TISC_QUAD; Const ConSettings: PZConSettings);
  end;

implementation

uses
{$IFNDEF FPC}
  Variants,
{$ENDIF}
  SysUtils, ZDbcUtils, ZEncoding;

{ TZInterbase6ResultSet }

{**
  Releases this <code>ResultSet</code> object's database and
  JDBC resources immediately instead of waiting for
  this to happen when it is automatically closed.

  <P><B>Note:</B> A <code>ResultSet</code> object
  is automatically closed by the
  <code>Statement</code> object that generated it when
  that <code>Statement</code> object is closed,
  re-executed, or is used to retrieve the next result from a
  sequence of multiple results. A <code>ResultSet</code> object
  is also automatically closed when it is garbage collected.
}
procedure TZInterbase6ResultSet.Close;
begin
  if FStmtHandle <> 0 then
  begin
    { Free output allocated memory }
    FSqlData := nil;
    { Free allocate sql statement }
    FreeStatement(FIBConnection.GetPlainDriver, FStmtHandle, DSQL_CLOSE); //AVZ
  end;
  inherited Close;
end;

{**
  Constructs this object, assignes main properties and
  opens the record set.
  @param Statement a related SQL statement object.
  @param handle a Interbase6 database connect handle.
  @param the statement previously prepared
  @param the sql out data previously allocated
  @param the Interbase sql dialect
}
constructor TZInterbase6ResultSet.Create(Statement: IZStatement; SQL: string;
  var StatementHandle: TISC_STMT_HANDLE; CursorName: AnsiString;
  SqlData: IZResultSQLDA; CachedBlob: boolean);
begin
  inherited Create(Statement, SQL, nil,
    Statement.GetConnection.GetConSettings);

  FFetchStat := 0;
  FSqlData := SqlData;
  FCursorName := CursorName;
  FCachedBlob := CachedBlob;
  FIBConnection := Statement.GetConnection as IZInterbase6Connection;

  FStmtHandle := StatementHandle;
  ResultSetType := rtForwardOnly;
  ResultSetConcurrency := rcReadOnly;
  FCodePageArray := (Statement.GetConnection.GetIZPlainDriver as IZInterbasePlainDriver).GetCodePageArray;
  FCodePageArray[ConSettings^.ClientCodePage^.ID] := ConSettings^.ClientCodePage^.CP; //reset the cp if user wants to wite another encoding e.g. 'NONE' or DOS852 vc WIN1250

  Open;
end;

{**
   Free memory and destriy component
}
destructor TZInterbase6ResultSet.Destroy;
begin
  if not Closed then
    Close;
  inherited Destroy;
end;

{**
   Return field value by it index
   @param the index column 0 first, 1 second ...
   @return the field value as variant type
}
function TZInterbase6ResultSet.GetFieldValue(ColumnIndex: Integer): Variant;
begin
  CheckClosed;
  Result := FSqlData.GetValue(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.BigDecimal</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param scale the number of digits to the right of the decimal point
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZInterbase6ResultSet.GetBigDecimal(ColumnIndex: Integer): Extended;
begin
  CheckClosed;
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBigDecimal);
{$ENDIF}
  Result := FSqlData.GetBigDecimal(ColumnIndex - 1);
  LastWasNull := IsNull(ColumnIndex);
end;

{**
  Returns the value of the designated column in the current row
  of this <code>ResultSet</code> object as a <code>Blob</code> object
  in the Java programming language.

  @param ColumnIndex the first column is 1, the second is 2, ...
  @return a <code>Blob</code> object representing the SQL <code>BLOB</code> value in
    the specified column
}
{$IFDEF FPC}
  {$HINTS OFF}
{$ENDIF}
function TZInterbase6ResultSet.GetBlob(ColumnIndex: Integer): IZBlob;
var
  Size: Integer;
  Buffer: Pointer;
  BlobId: TISC_QUAD;
begin
  Result := nil;
  CheckBlobColumn(ColumnIndex);

  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
      Exit;

  BlobId := FSqlData.GetQuad(ColumnIndex - 1);
  if FCachedBlob then
    try
      with FIBConnection do
        ReadBlobBufer(GetPlainDriver, GetDBHandle, GetTrHandle,
          BlobId, Size, Buffer, Self.GetMetaData.GetColumnType(ColumnIndex) = stBinaryStream,
          ConSettings);
      case GetMetaData.GetColumnType(ColumnIndex) of
        stBinaryStream:
          Result := TZAbstractBlob.CreateWithData(Buffer, Size);
        stAsciiStream, stUnicodeStream:
          Result := TZAbstractClob.CreateWithData(Buffer,
            Size, ConSettings^.ClientCodePage^.CP, ConSettings);
      end;
    finally
      FreeMem(Buffer, Size);
    end
  else
    case GetMetaData.GetColumnType(ColumnIndex) of
      stBinaryStream:
        Result := TZInterbase6UnCachedBlob.Create(FIBConnection.GetDBHandle,
          FIBConnection.GetTrHandle, FIBConnection.GetPlainDriver, BlobId,
          ConSettings);
      stAsciiStream, stUnicodeStream:
        Result := TZInterbase6UnCachedClob.Create(FIBConnection.GetDBHandle,
          FIBConnection.GetTrHandle, FIBConnection.GetPlainDriver, BlobId,
          ConSettings);
    end;
end;
{$IFDEF FPC}
  {$HINTS ON}
{$ENDIF}

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>boolean</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>false</code>
}
function TZInterbase6ResultSet.GetBoolean(ColumnIndex: Integer): Boolean;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBoolean);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    Result := False
  else
    Result := FSqlData.GetBoolean(ColumnIndex - 1);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>byte</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZInterbase6ResultSet.GetByte(ColumnIndex: Integer): Byte;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stByte);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    Result := 0
  else
    Result := FSqlData.GetByte(ColumnIndex - 1);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>byte</code> array in the Java programming language.
  The bytes represent the raw values returned by the driver.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZInterbase6ResultSet.GetBytes(ColumnIndex: Integer): TByteDynArray;
begin
  CheckClosed;
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBytes);
{$ENDIF}
  Result := FSqlData.GetBytes(ColumnIndex - 1);
  LastWasNull := IsNull(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Date</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZInterbase6ResultSet.GetDate(ColumnIndex: Integer): TDateTime;
begin
  CheckClosed;
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stDate);
{$ENDIF}
  Result := FSqlData.GetDate(ColumnIndex - 1);
  LastWasNull := IsNull(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>double</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZInterbase6ResultSet.GetDouble(ColumnIndex: Integer): Double;
begin
  CheckClosed;
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stDouble);
{$ENDIF}
  Result := FSqlData.GetDouble(ColumnIndex - 1);
  LastWasNull := IsNull(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>float</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZInterbase6ResultSet.GetFloat(ColumnIndex: Integer): Single;
begin
  CheckClosed;
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stFloat);
{$ENDIF}
  Result := FSqlData.GetFloat(ColumnIndex - 1);
  LastWasNull := IsNull(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  an <code>int</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZInterbase6ResultSet.GetInt(ColumnIndex: Integer): Integer;
begin
  CheckClosed;
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stInteger);
{$ENDIF}
  Result := FSqlData.GetInt(ColumnIndex - 1);
  LastWasNull := IsNull(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>long</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZInterbase6ResultSet.GetLong(ColumnIndex: Integer): Int64;
begin
  CheckClosed;
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stLong);
{$ENDIF}
  Result := FSqlData.GetLong(ColumnIndex - 1);
  LastWasNull := IsNull(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>short</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZInterbase6ResultSet.GetShort(ColumnIndex: Integer): SmallInt;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stShort);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    Result := 0
  else
    Result := FSqlData.GetShort(ColumnIndex - 1);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>String</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZInterbase6ResultSet.InternalGetString(ColumnIndex: Integer): RawByteString;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stString);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    Result := ''
  else
    Result := FSqlData.GetString(ColumnIndex - 1);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Time</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZInterbase6ResultSet.GetTime(ColumnIndex: Integer): TDateTime;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stTime);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    Result := 0
  else
    Result := FSqlData.GetTime(ColumnIndex - 1);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Timestamp</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
  value returned is <code>null</code>
  @exception SQLException if a database access error occurs
}
function TZInterbase6ResultSet.GetTimestamp(ColumnIndex: Integer): TDateTime;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stTimestamp);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    Result := 0
  else
    Result := FSqlData.GetTimestamp(ColumnIndex - 1);
end;

{**
  Indicates if the value of the designated column in the current row
  of this <code>ResultSet</code> object is Null.

  @param columnIndex the first column is 1, the second is 2, ...
  @return if the value is SQL <code>NULL</code>, the
    value returned is <code>true</code>. <code>false</code> otherwise.
}
function TZInterbase6ResultSet.IsNull(ColumnIndex: Integer): Boolean;
begin
  CheckClosed;
  Result := FSqlData.IsNull(ColumnIndex - 1);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>PAnsiChar</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param Len the Length of the PAnsiChar String
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZInterbase6ResultSet.GetAnsiRec(ColumnIndex: Integer): TZAnsiRec;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stString);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
  begin
    Result.P := nil;
    Result.Len := 0;
  end
  else
  begin
    Result := FSqlData.GetAnsiRec(ColumnIndex -1);
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>PAnsiChar</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZInterbase6ResultSet.GetPAnsiChar(ColumnIndex: Integer): PAnsiChar;
begin
  Result := GetAnsiRec(ColumnIndex).P;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>String</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZInterbase6ResultSet.GetString(ColumnIndex: Integer): String;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stString);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    Result := ''
  else
    {$IFDEF UNICODE}
    Result := ZAnsiRecToUnicode(FSqlData.GetAnsiRec(ColumnIndex -1),
      FCodePageArray[FSqlData.GetIbSqlSubType(ColumnIndex -1)]);
    {$ELSE}
    Result := ConSettings^.ConvFuncs.ZRawToString(FSqlData.GetString(ColumnIndex - 1),
      FCodePageArray[FSqlData.GetIbSqlSubType(ColumnIndex -1)], ConSettings^.CTRL_CP);
    {$ENDIF}
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>ZWideString</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZInterbase6ResultSet.GetUnicodeString(ColumnIndex: Integer): ZWideString;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stString);
{$ENDIF}
  LastWasNull := IsNull(ColumnIndex);
  if LastWasNull then
    Result := ''
  else
    Result := ZAnsiRecToUnicode(FSqlData.GetAnsiRec(ColumnIndex -1),
      FCodePageArray[FSqlData.GetIbSqlSubType(ColumnIndex -1)]);
end;

{**
  Moves the cursor to the given row number in
  this <code>ResultSet</code> object.

  <p>If the row number is positive, the cursor moves to
  the given row number with respect to the
  beginning of the result set.  The first row is row 1, the second
  is row 2, and so on.

  <p>If the given row number is negative, the cursor moves to
  an absolute row position with respect to
  the end of the result set.  For example, calling the method
  <code>absolute(-1)</code> positions the
  cursor on the last row; calling the method <code>absolute(-2)</code>
  moves the cursor to the next-to-last row, and so on.

  <p>An attempt to position the cursor beyond the first/last row in
  the result set leaves the cursor before the first row or after
  the last row.

  <p><B>Note:</B> Calling <code>absolute(1)</code> is the same
  as calling <code>first()</code>. Calling <code>absolute(-1)</code>
  is the same as calling <code>last()</code>.

  @return <code>true</code> if the cursor is on the result set;
    <code>false</code> otherwise
}
function TZInterbase6ResultSet.MoveAbsolute(Row: Integer): Boolean;
begin
  Result := False;
  RaiseForwardOnlyException;
end;

{**
  Moves the cursor down one row from its current position.
  A <code>ResultSet</code> cursor is initially positioned
  before the first row; the first call to the method
  <code>next</code> makes the first row the current row; the
  second call makes the second row the current row, and so on.

  <P>If an input stream is open for the current row, a call
  to the method <code>next</code> will
  implicitly close it. A <code>ResultSet</code> object's
  warning chain is cleared when a new row is read.

  @return <code>true</code> if the new current row is valid;
    <code>false</code> if there are no more rows
}
function TZInterbase6ResultSet.Next: Boolean;
var
  StatusVector: TARRAY_ISC_STATUS;
begin
  { Checks for maximum row. }
  Result := False;
  if (MaxRows > 0) and (LastRowNo >= MaxRows) then
    Exit;

  { Fetch row. }
  if (ResultSetType = rtForwardOnly) and (FFetchStat = 0) then
  begin
    with FIBConnection do
    begin
      if (FCursorName = '') then  //AVZ - Test for ExecProc - this is for multiple rows
      begin
        FFetchStat := GetPlainDriver.isc_dsql_fetch(@StatusVector,
          @FStmtHandle, GetDialect, FSqlData.GetData);
        //CheckInterbase6Error(GetPlainDriver, StatusVector, lcOther); //EH to test
      end
      else
      begin     //AVZ - Cursor name has a value therefore the result set already exists
        FFetchStat := 1;
        Result := True;
        //FStmtHandle := nil;  //AVZ TEST
      end;
    end;

    if FFetchStat = 0 then
    begin
      RowNo := RowNo + 1;
      LastRowNo := RowNo;
      Result := True;
    end;
  end;
end;

{**
  Opens this recordset.
}
procedure TZInterbase6ResultSet.Open;
var
  I: Integer;
  FieldSqlType: TZSQLType;
  ColumnInfo: TZColumnInfo;
begin
  if FStmtHandle=0 then
    raise EZSQLException.Create(SCanNotRetrieveResultSetData);

  ColumnsInfo.Clear;
  for I := 0 to FSqlData.GetFieldCount - 1 do
  begin
    ColumnInfo := TZColumnInfo.Create;
    with ColumnInfo, FSqlData  do
    begin
      ColumnName := GetFieldSqlName(I);
      TableName := GetFieldRelationName(I);
      ColumnLabel := GetFieldAliasName(I);
      FieldSqlType := GetFieldSqlType(I);
      ColumnType := FieldSqlType;

      if FieldSqlType in [stString, stUnicodeString] then
        ColumnCodePage := FCodePageArray[GetIbSqlSubType(I)]
      else if FieldSqlType in [stAsciiStream, stUnicodeStream] then
        ColumnCodePage := ConSettings^.ClientCodePage^.CP
      else
        ColumnCodePage := zCP_NONE;

      if FieldSqlType in [stBytes, stString, stUnicodeString] then
      begin
        MaxLenghtBytes := GetFieldLength(I);
        if (FSqlData.GetIbSqlType(I) = SQL_TEXT) or ( FieldSQLType = stBytes ) then
        begin
          if not ( FieldSQLType = stBytes ) then
            if ConSettings.ClientCodePage^.ID = CS_NONE then
          else
            ColumnDisplaySize := MaxLenghtBytes div ConSettings.ClientCodePage^.CharWidth;
          Precision := MaxLenghtBytes;
        end
        else
          Precision := GetFieldSize(ColumnType, ConSettings, MaxLenghtBytes,
            ConSettings^.ClientCodePage^.CharWidth, @ColumnDisplaySize, True);
      end;

      ReadOnly := (GetFieldRelationName(I) = '') or (GetFieldSqlName(I) = '')
        or (GetFieldSqlName(I) = 'RDB$DB_KEY') or (FieldSqlType = ZDbcIntfs.stUnknown);

      if IsNullable(I) then
        Nullable := ntNullable
      else
        Nullable := ntNoNulls;

      Scale := GetFieldScale(I);
      AutoIncrement := False;
      //Signed := False;
      //CaseSensitive := True;
    end;
    ColumnsInfo.Add(ColumnInfo);
  end;
  inherited Open;
end;

function TZInterbase6ResultSet.GetCursorName: AnsiString;
begin
  Result := FCursorName;
end;

{ TZInterbase6UnCachedBlob }
{**
  Reads the blob information by blob handle.
  @param handle a Interbase6 database connect handle.
  @param the statement previously prepared
}
constructor TZInterbase6UnCachedBlob.Create(const DBHandle: PISC_DB_HANDLE;
  const TrHandle: PISC_TR_HANDLE; const PlainDriver: IZInterbasePlainDriver;
  var BlobId: TISC_QUAD;Const ConSettings: PZConSettings);
begin
  FBlobId := BlobId;
  FDBHandle := DBHandle;
  FTrHandle := TrHandle;
  FPlainDriver := PlainDriver;
  FConSettings := ConSettings;
end;

{$IFDEF FPC}
  {$HINTS OFF}
{$ENDIF}
procedure TZInterbase6UnCachedBlob.ReadLob;
var
  Size: Integer;
  Buffer: Pointer;
begin
  InternalClear;
  ReadBlobBufer(FPlainDriver, FDBHandle, FTrHandle, FBlobId, Size, Buffer, True, FConSettings);
  BlobSize := Size;
  BlobData := Buffer;
  inherited ReadLob;
end;
{$IFDEF FPC}
  {$HINTS ON}
{$ENDIF}

{ TZInterbase6UnCachedClob }

{**
  Reads the blob information by blob handle.
  @param handle a Interbase6 database connect handle.
  @param the statement previously prepared
}
constructor TZInterbase6UnCachedClob.Create(const DBHandle: PISC_DB_HANDLE;
  const TrHandle: PISC_TR_HANDLE; const PlainDriver: IZInterbasePlainDriver;
  var BlobId: TISC_QUAD; const ConSettings: PZConSettings);
begin
  inherited CreateWithData(nil, 0, ConSettings^.ClientCodePage^.CP, ConSettings);
  FBlobId := BlobId;
  FDBHandle := DBHandle;
  FTrHandle := TrHandle;
  FPlainDriver := PlainDriver;
end;

{$IFDEF FPC}
  {$HINTS OFF}
{$ENDIF}
procedure TZInterbase6UnCachedClob.ReadLob;
var
  Size: Integer;
  Buffer: Pointer;
begin
  InternalClear;
  ReadBlobBufer(FPlainDriver, FDBHandle, FTrHandle, FBlobId, Size, Buffer, False, FConSettings);
  (PAnsiChar(Buffer)+NativeUInt(Size))^ := #0; //add #0 terminator
  FBlobSize := Size+1;
  BlobData := Buffer;
  inherited ReadLob;
end;
{$IFDEF FPC}
  {$HINTS ON}
{$ENDIF}

end.