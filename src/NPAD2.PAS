program Nostrum_Paddle_War;
uses crt,dos,ModeXLib,Gif,Sprites,mouse,fliplay,font,
     sblast,modplay,mixer;

type paddle = record
                x,y,col,hit:LongInt;
              end;

     ball   = Record
                x,y,col,ud,lr  :Integer;
              End;
     Block=Array[0..99,0..319] of Byte;
            

Const Sprite_Anzahl=12;
var paddle1,paddle2 : paddle;
    ballobj         : ball;
    outofscr,
    Sc1,Sc2,
    MatchBall,
    Method,
    del,
    stufe,
    increase,
    spielzahl,
    error,
    temporary       : Integer;
    button          : word;
    fly,
    broken,
    last,
    back,
    quit,
    man,
    cpu,
    bmenu,
    pause           : Boolean;
    ch              : Char;
    Sprite          : Array[1..Sprite_Anzahl] of SpriteTyp;
    config          : text;
    ef              : Array[1..5] of effect_type;

    Src_Frame,
    Dest_Frame      : ^Block;


Function Path : String;
var ParamDir:String;
    i:Integer;
begin
  ParamDir:=ParamStr(0);
  i:=Pos('.',ParamDir);
  while ParamDir[i] <> '\' do Dec(i);
  Path:=Copy(Paramdir,0,i-1);
end;

function FileExists(FileName: string)
                                : Boolean;
{ Returns True if file exists; otherwise,
  it returns False. Closes the file if
  it exists. }
var
  f: file;
begin
  {$I-}
  Assign(f, FileName);
  Reset(f);
  Close(f);
  {$I+}
  FileExists := (IOResult = 0) and
   (FileName <> '');
end;  { FileExists }

function IntToStr(i: Longint): string;
{ Convert any Integer type to a string }
var
  s: string[11];
begin
  Str(i, s);
  IntToStr := s;
end;

procedure init_The_Mod;
begin;
  mod_Setloopflag(ON);
  init_sb;
  mod_Samplefreq(22);
end;

procedure Play_the_Mod(s : string);
var h : byte;
    
begin;
  mod_Samplefreq(22);
  error := lade_moddatei(s,AUTO,AUTO);
  if error <> 0 then begin
    textmode(3);
    clrscr;
    writeln('Fehler beim Laden der ',
      ' Modul-Datei '+ s +' !');
    if error = -1 then writeln(
      'Initialisierung fehlerhaft !');
    if error = -2 then writeln(
      'Datei nicht gefunden !');
    halt(0);
  end;
  mli := 0;
  mlj := 0;
  periodisch_on;
end;


Procedure Scroll_Up;assembler;
{scrollt das Bild um eine Zeile nach oben und interpoliert}
asm
  push ds
  les di,Dest_Frame             {Zeiger auf Zielbild laden}
  lds si,Src_Frame              {Zeiger auf Quellbild}
  add si,320                    {im Quellbild auf Zeile 1}
  mov cx,320*98                 {99 Zeilen scrollen}
  xor bl,bl                     {wird als Dummy fr High-Byte ben”tigt}
@lp1:
  xor ax,ax
  xor bx,bx
  mov al,[si-321]               {ersten Punkt holen}
  mov bl,[si-320]               {zweiten Punkt addieren}
  add ax,bx
  mov bl,[si-319]               {n„chsten Punkt addieren}
  add ax,bx
  mov bl,[si-1]                 {usw...}
  add ax,bx
  mov bl,[si+1]
  add ax,bx
  mov bl,[si+319]
  add ax,bx
  mov bl,[si+320]
  adc ax,bx
  mov bl,[si+321]
  adc ax,bx
  shr ax,3

  or ax,ax                      {bereits 0 ?}
  je @null
  dec al                        {wenn nein, dann verringern}
@null:
  stosb                         {Wert ins Ziel}
  inc si                        {n„chsten Punkt}
  dec cx                        {weitere Punkte ?}
  jne @lp1
  pop ds
End;

Procedure New_Line;             {baut die untersten Zeilen neu auf}
Var i,x:Word;
Begin
  For x:=0 to 319 do Begin      {untere 3 Zeilen mit zuf„lligen Werten fllen}
    Dest_Frame^[97,x]:=Random(15)+64;
    Dest_Frame^[98,x]:=Random(15)+64;
    Dest_Frame^[99,x]:=Random(15)+64;
  End;
  For i:=0 to Random(45) do Begin {zuf. Anzahl Hotspots einfgen}
    x:=Random(320);             {an zuf„llige Koordinaten}
    asm
      les di,Dest_Frame         {Zielbild adressieren}
      add di,98*320             {Zeile 98 (zweitunterste) bearbeiten}
      add di,x                  {x-Koordinate dazu}
      mov al,0ffh               {hellste Farbe}
      mov es:[di-321],al        {groáen Hotspot erzeugen (9 Punkte)}
      mov es:[di-320],al
      mov es:[di-319],al
      mov es:[di-1],al
      mov es:[di],al
      mov es:[di+1],al
      mov es:[di+319],al
      mov es:[di+320],al
      mov es:[di+321],al
    End;
  End;
End;

Procedure Show_Screen;          {kopiert fertigen Bilschirm auf VGA}
Var temp:Pointer;               {zum Tauschen der Zeiger}
Begin
asm
  push ds
  lds si,Dest_Frame             {fertiges Bild als Quelle}
  mov ax,0a000h                 {VGA als Ziel}
  mov es,ax
  mov di,320*100                {ab Zeile 100}
  mov cx,320*100/4              {100 Zeilen als Dwords kopieren}
db 66h                          {Operand Size Prefix (32 Bit)}
  rep movsw                     {kopieren}
  pop ds
End;
  temp:=Dest_Frame;             {Zeiger auf Quell- und Zielbild tauschen}
  Dest_Frame:=Src_Frame;
  Src_Frame:=temp;
End;

Procedure Prep_Pal;             {Palette auf Flames vorbereiten}
Var i:Word;
Begin
  FillChar(Palette,80*3,0);     {Grundlage: alles schwarz}
  For i:=0 to 7 do Begin
    Palette[i*3+2]:=i*2;        {Farbe 0-7: Anstieg Blau}
    Palette[(i+8)*3+2]:=16-i*2; {Farbe 0-7: abfallendes Blau}
  End;
  For i:=8 to 31 do             {Farbe 8 -31: Anstieg Rot}
    Palette[i*3]:=(i-8)*63 div 23;
  For i:=32 to 55 do Begin      {Farbe 32-55: Anstieg Grn, Rot konstant}
    Palette[i*3]:=63;
    Palette[i*3+1]:=(i-32)*63 div 23;
  End;
  For i:=56 to 79 do Begin      {Farbe 56-79: Anstieg Blau,Rot u. Blau konst.}
    Palette[i*3]:=63;
    Palette[i*3+1]:=63;
    Palette[i*3+2]:=(i-56)*63 div 23;
  End;
  FillChar(Palette[80*3],176*3,63);  {Rest weiá}
  SetPal;                       {fertige Palette setzen}
End;

procedure flames;
begin
   
  Init_Mode13;                  {Mode 13h setzen}
                      {Palette vorbereiten}
  loadgif(Path+'\wait');
  show_pic13;
  Prep_Pal;
  Repeat
    Scroll_Up;                  {Flammen nach oben}
    New_Line;                   {unten neue Linie anfgen}
    Show_Screen;                {fertigen Bildschirm zeigen}
    if keypressed then ch:=readkey;
  Until ch=#13;
  Init_Modex;
end;

function LeftButtonPressed : boolean;
begin
  LeftButtonPressed:=false;
  if MouseButton=1 then LeftButtonPressed:=true;
end;
function RightButtonPressed : boolean;
begin
  RightButtonPressed:=false;
  if MouseButton=2 then RightButtonPressed:=true;
end;
function MI(x,y,x1,y1:integer) : boolean;
begin                                
  mi:=false;
  if (mousex>=x)and(mousex<=x1)and(mousey>=y)and(mousey<=y1) then mi:=true;
end;

procedure CompPositions;
begin
  if ballobj.x<=12 then begin

    if Ballobj.y In [Paddle1.y-15..Paddle1.y+61] then begin
      starte_soundeffekt(ef[2],11025,64,PC);
      ballobj.lr:=1;
      if Ballobj.y <= Paddle1.y+20 then begin
        ballobj.ud:=2;
      end else ballobj.ud:=1;
    end else OutofScr:=1;
  end else
  if ballobj.x>=281 then begin
    
    if ballobj.y In [Paddle2.y-15..Paddle2.y+61] then begin
      starte_soundeffekt(ef[2],11025,64,PC);
      ballobj.lr:=2;
      if Ballobj.y <= Paddle2.y+20 then begin
        ballobj.ud:=2;
      end else ballobj.ud:=1;
    end else OutOfScr:=2;
  end;
end;

procedure GetInputs;
begin {stearing}
  if man then begin
    if keypressed then begin
      ch:=readkey;
      case Upcase(ch) of
        #80 : begin
                Inc(paddle1.y,12);
                if paddle1.y>153 then paddle1.y:=153;
              end;
        #72 : begin
                Dec(paddle1.y,12);
                if paddle1.y<19 then paddle1.y:=19;
              end;
      end;
    end;
  end else
  if cpu then begin
    if outofscr=2 then begin
      paddle1.y:=Random(134)+19;
      if Random(3)=1 then fly:=true;
    end
    else begin
      if stufe=1 then if Random(5)=0 then Paddle1.y:=Ballobj.y-10;
      if stufe=2 then if Random(4)=0 then Paddle1.y:=Ballobj.y-10;
      if stufe=3 then if Random(3)=0 then Paddle1.y:=Ballobj.y-10;
    end;
    if paddle1.y>153 then paddle1.y:=153;
    if paddle1.y<19 then paddle1.y:=19;

  end;

  begin
    paddle2.y:=mousey;
    if paddle2.y>153 then paddle2.y:=153;
    if paddle2.y<19 then paddle2.y:=19;
  end;

end;

procedure OutOfScreen;                         
begin
  fly:=false;
  last:=false;
  if outofScr=1 then begin
    Inc(Sc2);
    if sc2>=matchball then last:=true;
  end
  Else
  if outofScr=2 then begin
    Inc(Sc1);
    if sc1>=matchball then last:=true;
  end;
  if (outofscr<>0)And(Method=1) then begin
    ballobj.x:=Random(230)+10;
    ballobj.y:=20;
    ballobj.ud:=1;
    ballobj.lr:=Random(2)+1;
    repeat
      CopyScreen(vpage,32000);
      GetInputs;
      PrintString(115,0,Inttostr(sc1)+':'+Inttostr(sc2));
      With Sprite[5] do Begin
        Dec(px,sx);  {Bewegung}
        If (px <= -dtx) Then Sprite[5].px:=310;
        PutSprite(vpage,px,py,Sprite[5]);
      End;
      PutSprite(vpage,paddle1.x,paddle1.y,Sprite[3]);
      PutSprite(vpage,paddle2.x,paddle2.y,Sprite[4]);
      PutSprite(vpage,115,90,Sprite[9]);
      modexlib.switch;
      pal_rot(30,15);
      mod_waitretrace ;
      setpal;
    Until (LeftButtonPressed=true)or(Keypressed);

  end else
  if (Method=2)and(last=false) then begin

  if outofscr=1 then begin
    ballobj.lr:=2;
    repeat                              
      CopyScreen(vpage,32000);
      GetInputs;                     
      ballobj.x:=289;
      ballobj.y:=paddle2.y+23;
      ballobj.ud:=Random(2)+1;
      
      PrintString(115,0,Inttostr(sc1)+':'+Inttostr(sc2));

      With Sprite[5] do Begin
        Dec(px,sx);  {Bewegung}
        If (px <= -dtx) Then Sprite[5].px:=310;
        PutSprite(vpage,px,py,Sprite[5]);
      End;
      PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
      PutSprite(vpage,paddle1.x,paddle1.y,Sprite[3]);
      PutSprite(vpage,paddle2.x,paddle2.y,Sprite[4]);
      modexlib.switch;
      pal_rot(30,15);
      mod_waitretrace ;
      setpal;
      if LeftButtonPressed=true then Fly:=true;
      if RightButtonPressed=true then begin broken:=true; exit end;
      if keypressed then begin
        ch:=readkey;
        if ch=#27 then begin broken:=true; exit end;
      end;
    Until fly=True;
    outofscr:=0;
  end else
  if outofscr=2 then begin
    ballobj.lr:=1;                           
    repeat
      CopyScreen(vpage,32000);
      GetInputs;
      ballobj.x:=12;
      ballobj.y:=paddle1.y+23;
      ballobj.ud:=Random(2)+1;
     
      PrintString(115,0,Inttostr(sc1)+':'+Inttostr(sc2));

      With Sprite[5] do Begin
        Dec(px,sx);  {Bewegung}
	If (px <= -dtx) Then Sprite[5].px:=310;
        PutSprite(vpage,px,py,Sprite[5]);
      End;
      PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
      PutSprite(vpage,paddle1.x,paddle1.y,Sprite[3]);
      PutSprite(vpage,paddle2.x,paddle2.y,Sprite[4]);
      modexlib.switch;
      pal_rot(30,15);
      mod_waitretrace ;
      setpal;
      if RightButtonPressed then begin Broken:=true; exit end;
      
      if keypressed then begin
        ch:=readkey;
        if ch=' ' then fly:=true;
        if ch=#27 then begin broken:=true; exit end;
      end;
    Until fly=True;
    outofscr:=0;
  end;
  end;
end;

procedure play;
begin
  repeat
    CopyScreen(vpage,32000);
    GetInputs;
    PrintString(115,0,Inttostr(sc1)+':'+Inttostr(sc2));
    With Sprite[5] do Begin
      Dec(px,sx);  {Bewegung}
      If (px <= -dtx) Then Sprite[5].px:=310;
      PutSprite(vpage,px,py,Sprite[5]);
    End;
    PutSprite(vpage,paddle1.x,paddle1.y,Sprite[3]);
    PutSprite(vpage,paddle2.x,paddle2.y,Sprite[4]);
    PutSprite(vpage,115,90,Sprite[10]);
    modexlib.switch;
    pal_rot(30,15);
    mod_waitretrace ;
    setpal;

  Until (LeftButtonPressed=true)or(Keypressed);

  repeat
    CopyScreen(vpage,32000);
       
    GetInputs;

    CompPositions;
    OutOfScreen;
    outofscr:=0;

    if Ballobj.y<=26 then begin starte_soundeffekt(ef[1],11025,64,PC); ballobj.ud:=1; end else
    if Ballobj.y>=176 then begin starte_soundeffekt(ef[1],11025,64,PC); ballobj.ud:=2; end;
                 

    begin
      if ballobj.ud=1 then Inc(ballobj.y,del) else
      if ballobj.ud=2 then Dec(ballobj.y,del);

      if ballobj.lr=1 then Inc(ballobj.x,del) else
      if ballobj.lr=2 then Dec(ballobj.x,del);
    end;

    PrintString(115,0,Inttostr(sc1)+':'+Inttostr(sc2));

    With Sprite[5] do Begin
      Dec(px,sx);  {Bewegung}
      If (px <= -dtx) Then Sprite[5].px:=310;
      PutSprite(vpage,px,py,Sprite[5]);
    End;

    PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
    PutSprite(vpage,paddle1.x,paddle1.y,Sprite[3]);
    PutSprite(vpage,paddle2.x,paddle2.y,Sprite[4]);
    modexlib.switch;                                    {wichtigst!!!!!!}
    pal_Rot(30,15);
    mod_waitretrace ;
    SetPal;
    if keypressed then begin
      ch:=readkey;
      if ch=#27 then broken:=true;
      if ch='p' then pause:=true;               
    end;
    if RightButtonPressed=true then broken:=true;
    if pause then repeat
      CopyScreen(vpage,32000);
      GetInputs;
      PrintString(115,0,Inttostr(sc1)+':'+Inttostr(sc2));
      With Sprite[5] do Begin
        Dec(px,sx);  {Bewegung}
        If (px <= -dtx) Then Sprite[5].px:=310;
        PutSprite(vpage,px,py,Sprite[5]);
      End;
      PutSprite(vpage,paddle1.x,paddle1.y,Sprite[3]);
      PutSprite(vpage,paddle2.x,paddle2.y,Sprite[4]);
      PutSprite(vpage,115,90,Sprite[10]);
      modexlib.switch;
      pal_rot(30,15);
      mod_waitretrace ;
      setpal;
      ch:='0';
      pause:=false;
    Until (LeftButtonPressed=true)or(Keypressed);
  Until (sc1=MatchBall)Or(Sc2=Matchball)or(broken=true);
  loadgif(Path+'\won');
  p13_2_modex(32000,16000);
  increase:=0;
  if broken=false then begin
  starte_soundeffekt(ef[3],11025,64,PC);
    repeat
      CopyScreen(vpage,32000);
      if sc1=matchball then Putsprite(vpage,20,increase,Sprite[11]);
      if sc2=matchball then PutSprite(vpage,20,increase,Sprite[12]);
      Inc(increase);
      modexlib.switch;
      mod_waitretrace ;
    Until (increase=200)or(Keypressed)or(LeftButtonPressed);
  end;
  loadgif(Path+'\main');
  p13_2_modex(32000,16000);
end;

procedure Ballo;
begin
  if Ballobj.y<=1 then begin starte_soundeffekt(ef[1],11025,64,PC); ballobj.ud:=1; end else
  if Ballobj.y>=178 then begin starte_soundeffekt(ef[1],11025,64,PC); ballobj.ud:=2; end;
  if Ballobj.x<=1 then begin starte_soundeffekt(ef[2],11025,64,PC); ballobj.lr:=1; end;
  if ballobj.x>=298 then begin starte_soundeffekt(ef[2],11025,64,PC); ballobj.lr:=2; end;

  begin
    if ballobj.ud=1 then Inc(ballobj.y,del) else
    if ballobj.ud=2 then Dec(ballobj.y,del);

    if ballobj.lr=1 then Inc(ballobj.x,del) else
    if ballobj.lr=2 then Dec(ballobj.x,del);
  end;
end;
  
procedure Menu;
begin
  GetMem(Src_Frame,320*100);    {Speicher fr Quellbild holen und l”schen}
  FillChar(Src_Frame^,320*100,0);
  GetMem(Dest_Frame,320*100);   {Speicher fr Ziellbild holen und l”schen}
  FillChar(Dest_Frame^,320*100,0);
  loadgif(Path+'\main');
  p13_2_modex(32000,16000);
  repeat
    CopyScreen(vpage,32000);

    if MI(90,70,220,90) then Rectangle(90,70,220,90,50);
    if MI(90,100,220,120) then Rectangle(90,100,220,120,50);
    if MI(90,130,220,150) then Rectangle(90,130,220,150,50);

    PutSprite(vpage,mousex,mousey,Sprite[6]);
    if (MI(90,70,220,90))and(LeftButtonPressed) then begin
      starte_soundeffekt(ef[4],11025,64,PC);
      ch:=#0;
      periodisch_off;
      ende_mod;
      play_the_mod(Path+'\betamind.mod');

      Flames;
      
      LoadGif(Path+'\npadback');
      p13_2_ModeX(32000,16000);
      
      With Sprite[5] do Begin       {Koordinaten und Geschwindigkeiten}
        px:=299;py:=2;            {aller drei Sprites auf (willkrliche) Werte}
        sx:=2;sy:=0;
      End;

      broken:=false;
           
      Sc1:=0;
      Sc2:=0;

      Paddle1.x:=1;
      Paddle2.x:=307;
      ballobj.x:=Random(230)+10;

      Paddle1.y:=20;
      Paddle2.y:=20;
      ballobj.y:=20;

      ballobj.ud:=1;
      ballobj.lr:=Random(2)+1;
      inc(spielzahl);
      play;
      repeat Until Leftbuttonpressed=false;
      periodisch_off;
      ende_mod;
      play_the_mod(Path+'\live.mod');
    end;
    if (MI(90,100,220,120))and(LeftButtonPressed) then begin
      starte_soundeffekt(ef[5],11025,64,PC);
      loadgif(Path+'\options');
      p13_2_modex(48000,16000);

      ballobj.x:=Random(230)+20; ballobj.y:=10; ballobj.ud:=1; ballobj.lr:=Random(2)+1;
      ballobj.col:=2;

      back:=false;
      repeat
        CopyScreen(vpage,48000);

        if MI(140,60,170,80) then Rectangle(140,60,170,80,50);
        if mi(180,60,210,80) then Rectangle(180,60,210,80,50);
        if Mi(179,126,196,140) then Rectangle(179,126,196,140,50);
        if Mi(285,126,302,140) then Rectangle(285,126,302,140,50);
        if Mi(140,90,170,110) then Rectangle(140,90,170,110,51);
        if Mi(180,90,210,110) then Rectangle(180,90,210,110,51);
        if Mi(220,90,250,110) then Rectangle(220,90,250,110,51);
        if MI(20,120,120,140) then Rectangle(20,120,120,140,50);
        if Mi(284,60,302,70) then Rectangle(284,60,302,70,50);
        if Mi(284,93,302,103) then Rectangle(284,93,302,103,50);

        Printstring(260,74,Inttostr(matchball));
        PrintString(212,60,Inttostr(del));
        if cpu then Putsprite(vpage,180,127,Sprite[7]);
        if man then Putsprite(vpage,286,127,Sprite[7]);
        PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
        PutSprite(vpage,mousex,mousey,Sprite[6]);

        

        if (MI(140,60,170,80))and (LeftButtonPressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          Inc(del);
          if del>=25 then del:=25;
          repeat
            CopyScreen(vpage,48000);
            Printstring(260,74,Inttostr(matchball));
            PrintString(212,60,Inttostr(del));
            if cpu then Putsprite(vpage,180,127,Sprite[7]);
            if man then Putsprite(vpage,286,127,Sprite[7]);
            PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
            PutSprite(vpage,mousex,mousey,Sprite[6]);
            ballo;
            modexlib.switch;
            pal_rot(30,15);
            mod_waitretrace ;
            setpal;
          Until Leftbuttonpressed=false;
        end;
        if (mi(180,60,210,80)) and (LeftButtonPressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          Dec(del);
          if del<1 then del:=1;
          repeat
            CopyScreen(vpage,48000);
            Printstring(260,74,Inttostr(matchball));
            PrintString(212,60,Inttostr(del));
            if cpu then Putsprite(vpage,180,127,Sprite[7]);
            if man then Putsprite(vpage,286,127,Sprite[7]);
            PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
            PutSprite(vpage,mousex,mousey,Sprite[6]);
            ballo;
            modexlib.switch;
            pal_rot(30,15);
            mod_waitretrace ;
            setpal;
          Until Leftbuttonpressed=false;
        end;
        if (Mi(179,126,196,140))and(LeftButtonPressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          bmenu:=false;
          man:=false;
          cpu:=true;
          repeat
            CopyScreen(vpage,48000);
            Printstring(260,74,Inttostr(matchball));
            PrintString(212,60,Inttostr(del));
            PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
            PutSprite(vpage,128,58,Sprite[8]);
            PutSprite(vpage,mousex,mousey,Sprite[6]);
            
            if (Mi(131,63,188,79))and(LeftButtonPressed) then begin
              starte_soundeffekt(ef[5],11025,64,PC);
              stufe:=1;
              bmenu:=true;
            end;
            if (Mi(131,81,188,96))and(LeftButtonPressed) then begin
              starte_soundeffekt(ef[5],11025,64,PC);
              stufe:=2;
              bmenu:=true;
            end;
            if (Mi(131,98,188,113))and(LeftButtonPressed) then begin
              starte_soundeffekt(ef[5],11025,64,PC);
              stufe:=3;
              bmenu:=true;
            end;
            ballo;
            modexlib.switch;
            pal_rot(30,15);
            mod_waitretrace ;
            setpal;
          Until bmenu=true;
          repeat
            CopyScreen(vpage,48000);
            Printstring(260,74,Inttostr(matchball));
            PrintString(212,60,Inttostr(del));
            if cpu then Putsprite(vpage,180,127,Sprite[7]);
            if man then Putsprite(vpage,286,127,Sprite[7]);
            PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
            PutSprite(vpage,mousex,mousey,Sprite[6]);
            ballo;
            modexlib.switch;
            pal_rot(30,15);
            mod_waitretrace ;
            setpal;
          Until Leftbuttonpressed=false;
        end;
        if (Mi(285,126,302,140))and(LeftButtonPressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          cpu:=false;
          man:=true;
        end;  
        if (Mi(140,90,170,110))and(LeftButtonPressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          Method:=2;
        end;
        if (Mi(180,90,210,110))and(LeftButtonPressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          Method:=1;
        end;
        if (Mi(220,90,250,110))and(LeftButtonPressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          Method:=0;
          Method:=Random(2)+1;
        end;
        if (MI(20,120,120,140))and(LeftButtonPressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          back:=true;
          repeat
            copyScreen(vpage,48000);
            Printstring(260,74,Inttostr(matchball));
            PrintString(212,60,Inttostr(del));
            if cpu then Putsprite(vpage,180,127,Sprite[7]);
            if man then Putsprite(vpage,286,127,Sprite[7]);
            PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
            PutSprite(vpage,mousex,mousey,Sprite[6]);
            ballo;
            modexlib.switch;
            pal_rot(30,15);
            mod_waitretrace ;
            setpal;
          Until Leftbuttonpressed=false;
        end;
        if (Mi(284,60,302,70))and(LeftButtonpressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          inc(matchball);
          if Matchball>50 then matchball:=50;
          repeat
            copyScreen(vpage,48000);
            Printstring(260,74,Inttostr(matchball));
            PrintString(212,60,Inttostr(del));
            if cpu then Putsprite(vpage,180,127,Sprite[7]);
            if man then Putsprite(vpage,286,127,Sprite[7]);
            PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
            PutSprite(vpage,mousex,mousey,Sprite[6]);
            ballo;
            modexlib.switch;
            pal_rot(30,15);
            mod_waitretrace ;
            setpal;
          Until Leftbuttonpressed=false;
        end;
        if (Mi(284,93,302,103))and(LeftButtonpressed) then begin
          starte_soundeffekt(ef[5],11025,64,PC);
          dec(matchball);
          if matchball<=1 then matchball:=1;
          repeat
            copyScreen(vpage,48000);
            Printstring(260,74,Inttostr(matchball));
            PrintString(212,60,Inttostr(del));
            if cpu then Putsprite(vpage,180,127,Sprite[7]);
            if man then Putsprite(vpage,286,127,Sprite[7]);
            PutSprite(vpage,ballobj.x,ballobj.y,Sprite[1]);
            PutSprite(vpage,mousex,mousey,Sprite[6]);
            ballo;
            modexlib.switch;
            pal_rot(30,15);
            mod_waitretrace ;
            setpal;
          Until Leftbuttonpressed=false;
        end;

        ballo;
               
        modexlib.switch;
        pal_rot(30,15);
        mod_waitretrace ;
        setpal;
      until back=true;
    end;
    if (MI(90,130,220,150))and LeftButtonPressed=true then begin
      starte_soundeffekt(ef[5],11025,64,PC);
      quit:=true;
    end;

    
     
    modexlib.switch;
    Pal_rot(30,15);
    mod_waitretrace;
    setpal;
  Until quit=true;
end;


begin
  Writeln('Nostrum Paddle Wars (C) 1997 NOSTRUM');
  Writeln('Version 0.9.5.4');
  Writeln('Doch!!!');
  Writeln('<Nur ohne Joystick :( !!!>');
  writeln;
  delay(5000);

  aaplay(Path+'\nostrum.fli');
  aaplay(Path+'\padwars.fli');

  init_the_mod;

  play_the_mod(Path+'\live.mod');

  write_sbconfig;

  error:=Lade_soundeffekt(path+'\bump1.voc',ef[1]);
  error:=Lade_soundeffekt(path+'\bump2.voc',ef[2]);
  error:=Lade_soundeffekt(path+'\ding.voc',ef[3]);
  error:=Lade_soundeffekt(path+'\ding2.voc',ef[4]);
  error:=Lade_soundeffekt(path+'\menue.voc',ef[5]);

  if mouseparams(button)=true then
    begin
      mouse_cursor(false);
      Randomize;

      Init_ModeX;
      LoadGif(Path+'\npadspr');
      GetSprite(28 + 56*320,25,24,Sprite[6]);
      GetSprite(21 + 1*320,18,20,Sprite[1]);
      GetSprite(94 + 1*320,11,46,Sprite[3]);
      GetSprite(151+ 1*320,11,46,Sprite[4]);
      GetSprite(68 + 63*320,16,13,Sprite[7]);
      GetSprite(128 + 58*320,62,60,Sprite[8]);

      Getem(11,3,21,22,'1',Path+'\font');
      GetEm(29,3,42,22,'2',Path+'\font');
      Getem(48,3,60,22,'3',Path+'\font');
      Getem(65,3,77,22,'4',Path+'\font');
      Getem(85,3,97,22,'5',Path+'\font');
      Getem(103,3,115,22,'6',Path+'\font');
      Getem(121,3,134,22,'7',Path+'\font');
      Getem(140,3,152,22,'8',Path+'\font');
      Getem(157,3,171,22,'9',Path+'\font');
      Getem(176,3,189,22,'0',Path+'\font');
      Getem(194,3,201,22,':',Path+'\font');

      LoadGif(Path+'\npadtext');           {Bild mit den drei Sprites laden}
      GetSprite(66 + 20*320,174,14,Sprite[5]);
      Getsprite(75 + 46*320,104,23,Sprite[9]);
      GetSprite(73 + 83*320,106,24,Sprite[10]);
      GetSprite(44 + 116*320,181,26,Sprite[11]);
      GetSprite(43 + 153*320,182,28,Sprite[12]);

      broken:=false;
      quit:=false;
      Sc1:=0;
      Sc2:=0;
      spielzahl:=0;

      if FileExists(Path+'\npad.cfg') then begin
        assign(config,Path+'\npad.cfg');
        reset(config);
        readln(config,temporary);
        if temporary=0 then cpu:=false else cpu:=true;
        readln(config,temporary);
        if temporary=0 then man:=false else man:=true;
        readln(config,stufe);
        readln(config,del);
        readln(config,Method);                  
        readln(config,matchball);
        close(config);
      end else begin
        cpu:=false;              
        man:=true;
        del:=10;
        Method:=2;
        matchball:=12;
      end;

      menu;

      TextMode(3);

      Writeln('Der "MatchBall" war :',MatchBall);
      writeln;
      writeln('<<<<<<<< ',sc1,'         ',sc2,' >>>>>>>>');
      writeln;
      if (sc1=Matchball)Or(Sc2=Matchball) then begin
        if Sc1>sc2 then Writeln('Spieler 1 hat gewonnen !!!!!!! Aplaus!!!!')
        else Writeln('Spieler 2 hat gewonnen !!!!!!! Aplaus!!!!');
        writeln;
        writeln('Es wurde ',spielzahl,' mal gespielt.');
      end else Writeln('Spiel wurde abgebrochen!');
      writeln;
      writeln('Dieses Spiel ist HARALD HAGN gewidmet!!!!!!');
      writeln;
      Writeln('Danke, dass Sie Nostrum Paddle Wars gespielt haben.');

      assign(config,Path+'\npad.cfg');
      rewrite(config);
      if cpu=false then temporary:=0 else temporary:=1;
      writeln(config,temporary);
      if man=false then temporary:=0 else temporary:=1;
      writeln(config,temporary);
      writeln(config,stufe);
      writeln(config,del);
      writeln(config,Method);
      writeln(config,matchball);
      Close(config);

      Halt(0);
    end
  else Writeln('Keine Maus gefunden.');
  readln;
  exit;
  halt(0);
end.