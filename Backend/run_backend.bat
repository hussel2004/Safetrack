@echo off
set PYTHON_EXE=C:\Users\j-store\AppData\Local\Programs\Python\Python314\python.exe
echo Using Python at %PYTHON_EXE%

echo Installing dependencies...
"%PYTHON_EXE%" -m pip install -r requirements.txt
echo.
echo Starting FastAPI Backend...
"%PYTHON_EXE%" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
