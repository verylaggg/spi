@ECHO OFF
@REM CLS
:Menu
    ECHO s. Simulation
    ECHO w. Waveform viewer
    ECHO b. Both
    ECHO e. Exit
    ECHO **Simulation is default option
    ECHO.
    SET M=s
    SET /P M=Input s, w, b, e then press ENTER:
    IF /I %M%==s GOTO Simulation
    IF /I %M%==w GOTO WaveformViewer
    IF /I %M%==b GOTO Simulation
    IF /I %M%==e GOTO End
    ECHO Invalid input
    ECHO.
    GOTO Menu

:Simulation
    del /q *.vcd *.vvp *.log >NUL
    iverilog -o "tb.vvp" -f "../sim/filelist.f" -g2012 > compile.log 2>&1
    vvp -n "tb.vvp" > simulate.log 2>&1
    type *.log
    IF /I %M%==s    GOTO End

:WaveformViewer
    start /b gtkwave tb.vcd --dark -r ./gtkwaverc.txt

:End
    IF /I %M%==s    pause
    exit
