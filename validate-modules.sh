#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(pwd)

# Find all directories containing at least one .tf file, ignoring any folder named "test"
MODULE_DIRS=$(find . -type f -name "*.tf" \
    ! -path "*/test/*" \
    -exec dirname {} \; | sort -u)

# Counters
total=0
passed=0
failed=0

# Colors
RED='\033[0;31m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD_NC='\033[1m'

echo ""
echo -e "${NC}🔍 Starting ${PURPLE}Terraform${NC} validation (ignoring 'test' folders)...${NC}"
echo ""

for MODULE in $MODULE_DIRS; do
    total=$((total + 1))
    echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🧭 ${NC}Module [$total]:${NC} $MODULE"

    cd "$MODULE" || {
        echo -e "  ${RED}❌ ERROR:${NC} Failed to enter directory $MODULE"
        failed=$((failed + 1))
        cd "$ROOT_DIR"
        continue
    }

    # Clean up previous artifacts
    rm -rf .terraform .terraform.lock.hcl validate_output.json terraform_validation.log

    # Run terraform init and capture error summary if it fails
    echo -e "  ${NC}→ Running ${PURPLE}terraform init${NC}...${NC}"
    if ! terraform init -backend=false > terraform_validation.log 2>&1; then
        # Extract a short summary from the init log
        short_error=$(grep -m1 -E "Error:|Failed to" terraform_validation.log | sed 's/^ *//')
        [[ -z "$short_error" ]] && short_error="Unknown init error"
        echo -e "  ${RED}❌  terraform init failed in ${MODULE}${NC} — ${YELLOW}${short_error}${NC}"
        failed=$((failed + 1))
        rm -rf .terraform .terraform.lock.hcl validate_output.json terraform_validation.log
        cd "$ROOT_DIR"
        continue
    fi

    wait

    # Run terraform validate
    echo -e "  ${NC}→ Running ${PURPLE}terraform validate${NC}...${NC}"
    if terraform validate -json > validate_output.json 2>&1; then
        echo -e "  ${BLUE}Validation passed${NC}"
        passed=$((passed + 1))
    else
        wait
        # Extract a short, human-readable error
        short_error=$(grep -Eo '"summary": *"[^"]+"' validate_output.json | head -n1 | sed -E 's/.*"summary": *"(.*)"/\1/')
        [[ -z "$short_error" ]] && short_error=$(grep -m1 -Eo 'Error: .+' validate_output.json | sed 's/^Error: //')
        [[ -z "$short_error" ]] && short_error="Unknown validation error"
        echo -e "  ${RED}❌  terraform validate failed in ${MODULE}${NC} — ${YELLOW}${short_error}${NC}"
        failed=$((failed + 1))
    fi

    # Cleanup per-module files
    rm -rf .terraform .terraform.lock.hcl validate_output.json terraform_validation.log

    cd "$ROOT_DIR"
done

# Final summary
echo ""
echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${NC}🏁 Validation Summary${NC}"
echo -e "----------------------"
echo -e "Passed:  $passed"
echo -e "Failed:  $failed"
echo -e "Total:   $total"
echo ""


