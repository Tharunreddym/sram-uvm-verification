# GitHub Push Instructions

Create a new GitHub repository named:

```text
sram-uvm-verification
```

Then run these commands from inside this folder:

```powershell
git init
git branch -M main
git add .
git commit -m "Initial SRAM UVM verification project with real EDA evidence"
git remote add origin https://github.com/Tharunreddym/sram-uvm-verification.git
git push -u origin main
```

If GitHub rejects the push because the remote has a README or other file, run:

```powershell
git pull origin main --allow-unrelated-histories
git push -u origin main
```

Do not claim UCDB/VDB merge unless you later run a local Questa/VCS/Xcelium coverage merge.
