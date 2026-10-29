# Rust apps with Qt Quick

The selected stack is Rust plus Qt Quick through cxx-qt. The shell remains Quickshell. Both consume one curated kit of plain Qt Quick controls and tokens. Android builds and LCARS are out of scope.

The existing spike loaded adapted shared controls in a cxx-qt app and Quickshell. It did not finish the production kit. App menu hosts and Win98 fractional scaling remain work for phase 1.

In the exploratory 10,000-row benchmark, cxx-qt used 128 MiB PSS and Quickshell used 144 MiB, with similar scrolling. Slint used less memory and started faster, but required a second theme implementation. The owner selected shared drawing and Qt app integration over that saving. The machine was heavily loaded, sample sizes differed and this is not a general ranking of toolkits.

cxx-qt is pre-1.0. Pin it and preserve its bridge-version compatibility. The scaffold does not add it as a dependency before a real Qt consumer exists.
