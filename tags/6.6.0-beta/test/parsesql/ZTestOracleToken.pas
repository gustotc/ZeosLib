{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{          Test Case for Oracle Tokenizer Classes         }
{                                                         }
{    Copyright (c) 1999-2004 Zeos Development Group       }
{            Written by Sergey Seroukhov                  }
{                                                         }
{*********************************************************}

{*********************************************************}
{ License Agreement:                                      }
{                                                         }
{ This library is free software; you can redistribute     }
{ it and/or modify it under the terms of the GNU Lesser   }
{ General Public License as published by the Free         }
{ Software Foundation; either version 2.1 of the License, }
{ or (at your option) any later version.                  }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ You should have received a copy of the GNU Lesser       }
{ General Public License along with this library; if not, }
{ write to the Free Software Foundation, Inc.,            }
{ 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA }
{                                                         }
{ The project web site is located on:                     }
{   http://www.sourceforge.net/projects/zeoslib.          }
{   http://www.zeoslib.sourceforge.net                    }
{                                                         }
{                                 Zeos Development Group. }
{*********************************************************}

unit ZTestOracleToken;

interface

uses TestFramework, ZClasses, ZTokenizer, ZOracleToken,
  ZTestTokenizer;

type

  {** Implements a test case for OracleTokenizer classes. }
  TZTestOracleTokenizer = class(TZAbstractTokenizerTestCase)
  protected
    procedure SetUp; override;
  published
    procedure TestWhitespaceState;
    procedure TestQuoteState;
    procedure TestCommentState;
    procedure TestSymbolState;
    procedure TestWordState;
    procedure TestNumberState;
  end;

implementation

{ TZTestOracleTokenizer }

{**
  Sets up the test environment before tests.
}
procedure TZTestOracleTokenizer.SetUp;
begin
  Tokenizer := TZOracleTokenizer.Create;
end;

{**
  Runs a test for comments.
}
procedure TZTestOracleTokenizer.TestCommentState;
const
  TokenString1: string = '-aaa/*bbb*/ccc--ddd'#10;
  TokenTypes1: array[0..5] of TZTokenType = (
    ttSymbol, ttWord, ttComment, ttWord, ttComment, ttWhitespace);
  TokenValues1: array[0..5] of string = (
    '-', 'aaa', '/*bbb*/', 'ccc', '--ddd', #10);
begin
  CheckTokens(Tokenizer.TokenizeBuffer(TokenString1, [toSkipEOF]),
    TokenTypes1, TokenValues1);
end;

{**
  Runs a test for quoted strings.
}
procedure TZTestOracleTokenizer.TestQuoteState;
const
  TokenString1: string = '"a""aa" ''cc''''c''';
  TokenTypes1: array[0..1] of TZTokenType = (
    ttWord, ttQuoted);
  TokenValues1: array[0..1] of string = (
    '"a""aa"', '''cc''''c''');
begin
  CheckTokens(Tokenizer.TokenizeBuffer(TokenString1,
    [toSkipEOF, toSkipWhitespaces]), TokenTypes1, TokenValues1);
end;

{**
  Runs a test for symbols.
}
procedure TZTestOracleTokenizer.TestSymbolState;
const
  TokenString1: string = '=<>>= < >';
  TokenTypes1: array[0..4] of TZTokenType = (
    ttSymbol, ttSymbol, ttSymbol, ttSymbol, ttSymbol);
  TokenValues1: array[0..4] of string = (
    '=', '<>', '>=', '<', '>');
begin
  CheckTokens(Tokenizer.TokenizeBuffer(TokenString1,
    [toSkipEOF, toSkipWhitespaces]), TokenTypes1, TokenValues1);
end;

{**
  Runs a test for whitespaces.
}
procedure TZTestOracleTokenizer.TestWhitespaceState;
const
  TokenString1: string = 'aaa '#9'ccc'#10#13;
  TokenTypes1: array[0..3] of TZTokenType = (
    ttWord, ttWhitespace, ttWord, ttWhitespace);
  TokenValues1: array[0..3] of string = (
    'aaa', ' '#9, 'ccc', #10#13);
begin
  CheckTokens(Tokenizer.TokenizeBuffer(TokenString1, [toSkipEOF]),
    TokenTypes1, TokenValues1);
end;

{**
  Runs a test for words.
}
procedure TZTestOracleTokenizer.TestWordState;
const
  TokenString1: string = ' _a_a. $b$b #p@2p';
  TokenTypes1: array[0..3] of TZTokenType = (
    ttWord, ttSymbol, ttWord, ttWord);
  TokenValues1: array[0..3] of string = (
    '_a_a', '.', '$b$b', '#p@2p');
begin
  CheckTokens(Tokenizer.TokenizeBuffer(TokenString1,
    [toSkipEOF, toSkipWhitespaces]), TokenTypes1, TokenValues1);
end;

{**
  Runs a test for quoted strings.
}
procedure TZTestOracleTokenizer.TestNumberState;
const
  TokenString1: string = '.A .123 123.456a 123.456e10 2E-12c';
  TokenTypes1: array[0..7] of TZTokenType = (
    ttSymbol, ttWord, ttFloat, ttFloat, ttWord, ttFloat, ttFloat, ttWord);
  TokenValues1: array[0..7] of string = (
    '.', 'A', '.123', '123.456', 'a', '123.456e10', '2E-12', 'c');
begin
  CheckTokens(Tokenizer.TokenizeBuffer(TokenString1,
    [toSkipEOF, toSkipWhitespaces]), TokenTypes1, TokenValues1);
end;

initialization
  TestFramework.RegisterTest(TZTestOracleTokenizer.Suite);
end.

