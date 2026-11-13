@echo off
chcp 65001 >nul 2>&1
:: ============================================================
:: 二次开发启动入口（Windows）
::
:: 作用：等价于 start.bat，但强制跳过「是否更新到最新代码」的询问。
:: 原因：一旦在那个询问里按 Y，start.bat 会执行
::         git checkout -f master + git reset --hard origin/master
::       直接丢掉 dev 分支上的所有未提交改动，并把你切回 master。
::       要更新上游，请用 ./sync-upstream.sh 可控地同步。
:: ============================================================
set "SAU_JUST_UPDATED=1"
call "%~dp0start.bat" %*
