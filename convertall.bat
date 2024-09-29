@echo off
setlocal enabledelayedexpansion

REM Iterate over all PDF files in the current directory
for %%f in (*.pdf) do (
    REM Extract the base name without extension
    set "basename=%%~nf"
    
    REM Run the Ruby script and redirect output
    ruby consorsbank2ledger.rb "%%f" > "!basename!.csv"
)

endlocal
