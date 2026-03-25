#!/bin/bash
# Create directories for reports
mkdir -p initialReports timingReports verifyReports clockReports powerReports densityReports finalReports extLogDir

# Run Innovus
innovus -files ./scripts/pnr.tcl || exit 1;
