#!/usr/bin/env bash
# One-time setup for housing_market_forecast.ipynb (macOS, Homebrew).
#
# Usage (from Terminal or the VS Code terminal):
#   cd housing-market-forecast
#   bash setup.sh
#
# Safe to re-run: it reuses .venv and skips anything already installed.
set -euo pipefail
cd "$(dirname "$0")"

say()  { printf "\n\033[1;34m==> %s\033[0m\n" "$1"; }
ok()   { printf "    \033[32m✓ %s\033[0m\n" "$1"; }
fail() { printf "    \033[31m✗ %s\033[0m\n" "$1"; exit 1; }

# ---------------------------------------------------------------- 1. Python
say "1/5  Checking Python"
PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null || fail "python3 not found. Install it with: brew install python@3.13"
"$PY" -c 'import sys; assert sys.version_info >= (3, 10), sys.version' \
    || fail "Python 3.10 or newer is needed (found $("$PY" --version))"
ok "$("$PY" --version) at $(command -v "$PY")"

# ---------------------------------------------------------------- 2. venv
say "2/5  Creating the virtual environment (.venv)"
if [ -x .venv/bin/python ]; then
    ok ".venv already exists, reusing it"
else
    "$PY" -m venv .venv
    ok "created .venv"
fi
VPY="$PWD/.venv/bin/python"

# ---------------------------------------------------------------- 3. packages
say "3/5  Installing packages from requirements.txt (a few minutes the first time)"
"$VPY" -m pip install --quiet --upgrade pip
"$VPY" -m pip install --quiet -r requirements.txt ipykernel
ok "packages installed"

"$VPY" -m ipykernel install --user --name housing-market-forecast --display-name "Python (housing-market-forecast)" >/dev/null
ok "registered Jupyter kernel \"Python (housing-market-forecast)\""

# ---------------------------------------------------------------- 4. Java
say "4/5  Checking Java (PySpark needs Java 17 or newer)"
JH=""
if /usr/libexec/java_home -v 17+ >/dev/null 2>&1; then
    JH="$(/usr/libexec/java_home -v 17+)"
else
    for p in /opt/homebrew/opt/openjdk@17 /opt/homebrew/opt/openjdk /usr/local/opt/openjdk@17 /usr/local/opt/openjdk; do
        [ -x "$p/bin/java" ] && JH="$p/libexec/openjdk.jdk/Contents/Home" && break
    done
fi
if [ -z "$JH" ]; then
    command -v brew >/dev/null || fail "No Java 17+ and no Homebrew. Install Homebrew (https://brew.sh), then re-run."
    echo "    Java 17+ not found, installing with Homebrew..."
    brew install openjdk@17
    JH="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
fi
[ -x "$JH/bin/java" ] || fail "Java install not found at $JH"
ok "Java: $("$JH/bin/java" -version 2>&1 | head -1)"
echo "$JH" > .java_home     # the notebook reads this, so you don't need to edit your shell profile

# ---------------------------------------------------------------- 5. smoke test
say "5/5  Testing the install"
JAVA_HOME="$JH" "$VPY" - <<'EOF'
import warnings; warnings.filterwarnings("ignore")
import numpy, pandas, sklearn, duckdb, pyspark, matplotlib, scipy
print(f"    numpy {numpy.__version__}, pandas {pandas.__version__}, scikit-learn {sklearn.__version__}, "
      f"duckdb {duckdb.__version__}, pyspark {pyspark.__version__}")
print("    duckdb test:", duckdb.sql("SELECT 41 + 1 AS answer").fetchone()[0])
from pyspark.sql import SparkSession
spark = SparkSession.builder.master("local[1]").config("spark.ui.enabled", "false").getOrCreate()
spark.sparkContext.setLogLevel("ERROR")
print("    spark test: counted", spark.range(1000).count(), "rows")
spark.stop()
EOF
ok "everything works"

for f in Metro_zhvi_uc_sfrcondo_tier_0.33_0.67_sm_sa_month.csv Metro_zori_uc_sfrcondomfr_sm_month.csv; do
    [ -f "data/$f" ] && ok "found data/$f" || echo "    ! missing data/$f (the notebook will use synthetic data)"
done

cat <<'EOF'

Done. Next:
  1. Open housing_market_forecast.ipynb in VS Code.
  2. Top right, click the kernel name -> Select Another Kernel -> Python Environments
     -> choose ".venv (Python 3.13)" (or "Python (housing-market-forecast)" under Jupyter Kernels).
  3. Run All. If you had the notebook open already, click Restart first.
EOF
