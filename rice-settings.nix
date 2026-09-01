{
  # The one file intended for normal tuning after installation.
  audio = {
    rate = 48000;
    # Stable music-production default for the i5-4300U. Set this to 1024 if a
    # project is unusually heavy and you care more about stability than latency.
    studioQuantum = 512;
    safeQuantum = 1024;
  };

  # Optional packages that are useful but not worth forcing into every install.
  optionalApps = {
    # Qt PipeWire patchbay. Great when you actually need visual routing, but it
    # pulls a larger Qt closure, so the minimal profile leaves it off by default.
    qpwgraph = false;
  };
}
