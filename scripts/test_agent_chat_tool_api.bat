@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0test_agent_chat_tool_api.ps1" %*
exit /b %ERRORLEVEL%
