#!/bin/bash
gdstyle fmt --check src tests
gdstyle check --max-warnings 0 src tests
