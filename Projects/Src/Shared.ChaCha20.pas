unit Shared.ChaCha20;

{
  Inno Setup
  Copyright (C) 1997-2024 Jordan Russell
  Portions by Martijn Laan
  For conditions of distribution and use, see LICENSE.TXT.

  ChaCha20 encryption/decryption

  Based on https://github.com/marcizhu/ChaCha20/blob/master/ChaCha20.h
  Copyright (c) 2022 Marc Izquierdo
  MIT License
}

interface

uses
  Windows;

type
  TChaChaCtx = array[0..15] of Cardinal;

  TChaChaContext = record
    ctx: TChaChaCtx;
  end;

procedure ChaCha20Init(var Context: TChaChaContext; const Key;
 const KeyLength: Cardinal; const Nonce; const NonceLength: Cardinal;
 const Count: Cardinal);
procedure ChaCha20Crypt(var Context: TChaChaContext; const InBuffer;
  var OutBuffer; Length: Cardinal);

implementation

uses
  SysUtils, Math;

procedure ChaCha20Init(var Context: TChaChaContext; const Key;
  const KeyLength: Cardinal; const Nonce; const NonceLength: Cardinal;
  const Count: Cardinal);

  function Pack4(const pData: PByte; const Index: Integer): Cardinal;
  begin
    Result := Cardinal(pData[Index]) or
              (Cardinal(pData[Index + 1]) shl 8) or
              (Cardinal(pData[Index + 2]) shl 16) or
              (Cardinal(pData[Index + 3]) shl 24);
  end;

begin
  Assert(KeyLength = 32);
  Assert(NonceLength = 12);
  {$IFDEF DEBUG}
  ZeroMemory(@Context, SizeOf(Context));
  {$ENDIF}
  Context.ctx[0] := $61707865;
  Context.ctx[1] := $3320646e;
  Context.ctx[2] := $79622d32;
  Context.ctx[3] := $6b206574;
  var Buf: PByte := @Key;
  for var I := 0 to 7 do
    Context.ctx[I + 4] := Pack4(Buf, I * 4);
  Context.ctx[12] := Count;
  Buf := @Nonce;
  for var I := 0 to 2 do
    Context.ctx[I + 13] := Pack4(Buf, i * 4);
end;

procedure ChaCha20Crypt(var Context: TChaChaContext; const InBuffer;
  var OutBuffer; Length: Cardinal);

  function ROTL(const x: Cardinal; const n: Byte): Cardinal;
  begin
    Result := (x shl n) or (x shr (32 - n));
  end;

  procedure CHACHA20_QR(var a, b, c, d: Cardinal);
  begin
    Inc(a, b); d := d xor a; d := ROTL(d, 16);
    Inc(c, d); b := b xor c; b := ROTL(b, 12);
    Inc(a, b); d := d xor a; d := ROTL(d, 8);
    Inc(c, d); b := b xor c; b := ROTL(b, 7);
  end;

  procedure ChaCha20BlockNext(const input: TChaChaCtx; var output: TChaChaCtx);
  begin
    for var i := 0 to 15 do
      output[i] := input[i];

    for var i := 0 to 9 do begin
      CHACHA20_QR(output[0], output[4], output[8], output[12]);  // column 0
      CHACHA20_QR(output[1], output[5], output[9], output[13]);  // column 1
      CHACHA20_QR(output[2], output[6], output[10], output[14]); // column 2
      CHACHA20_QR(output[3], output[7], output[11], output[15]); // column 3
      CHACHA20_QR(output[0], output[5], output[10], output[15]); // diagonal 1 (main diagonal)
      CHACHA20_QR(output[1], output[6], output[11], output[12]); // diagonal 2
      CHACHA20_QR(output[2], output[7], output[8], output[13]);  // diagonal 3
      CHACHA20_QR(output[3], output[4], output[9], output[14]);  // diagonal 4
    end;

    for var i := 0 to 15 do
      output[i] := output[i] + input[i];
  end;

begin
  var InBuf: PByte := @InBuffer;
  var OutBuf: PByte := @OutBuffer;
  while Length > 0 do begin
    var Tmp: TChaChaCtx;
    ChaCha20BlockNext(Context.ctx, Tmp);
    Context.ctx[12] := Context.ctx[12] + 1;
    if Context.ctx[12] = 0 then begin
      Context.ctx[13] := Context.ctx[13] + 1;
      Assert(Context.ctx[13] <> 0);
    end;

    var KeyStream: PByte := @Tmp;
    var BlockSize := Min(Length, 64);
    for var I := 0 to  BlockSize - 1 do
      OutBuf[I] := InBuf[I] xor KeyStream[i];

    InBuf := PByte(NativeUInt(InBuf)+BlockSize);
    OutBuf := PByte(NativeUInt(OutBuf)+BlockSize);
    Dec(Length, BlockSize);
  end;
end;

end.
