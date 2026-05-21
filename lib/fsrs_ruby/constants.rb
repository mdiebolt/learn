# frozen_string_literal: true

module FsrsRuby
  module Constants
    # Default configuration values
    DEFAULT_REQUEST_RETENTION = 0.9
    DEFAULT_MAXIMUM_INTERVAL = 36500
    DEFAULT_ENABLE_FUZZ = false
    DEFAULT_ENABLE_SHORT_TERM = true
    DEFAULT_LEARNING_STEPS = ['1m', '10m'].freeze
    DEFAULT_RELEARNING_STEPS = ['10m'].freeze

    # Stability bounds
    S_MIN = 0.001
    S_MAX = 36500.0
    INIT_S_MAX = 100.0

    # Decay values
    FSRS5_DEFAULT_DECAY = 0.5
    FSRS6_DEFAULT_DECAY = 0.1542

    # W17_W18 ceiling for parameter clamping
    W17_W18_CEILING = 2.0

    # Default weights (w[0] through w[20])
    DEFAULT_WEIGHTS = [
      0.212,   # w[0]: initial stability (Again)
      1.2931,  # w[1]: initial stability (Hard)
      2.3065,  # w[2]: initial stability (Good)
      8.2956,  # w[3]: initial stability (Easy)
      6.4133,  # w[4]: initial difficulty (Good)
      0.8334,  # w[5]: initial difficulty (multiplier)
      3.0194,  # w[6]: difficulty (multiplier)
      0.001,   # w[7]: difficulty (multiplier)
      1.8722,  # w[8]: stability (exponent)
      0.1666,  # w[9]: stability (negative power)
      0.796,   # w[10]: stability (exponent)
      1.4835,  # w[11]: fail stability (multiplier)
      0.0614,  # w[12]: fail stability (negative power)
      0.2629,  # w[13]: fail stability (power)
      1.6483,  # w[14]: fail stability (exponent)
      0.6014,  # w[15]: stability (multiplier for Hard)
      1.8729,  # w[16]: stability (multiplier for Easy)
      0.5425,  # w[17]: short-term stability (exponent)
      0.0912,  # w[18]: short-term stability (exponent)
      0.0658,  # w[19]: short-term last-stability (exponent)
      FSRS6_DEFAULT_DECAY # w[20]: decay
    ].freeze

    # Parameter clamping ranges
    # Returns array of [min, max] pairs for each weight
    def self.clamp_parameters(w17_w18_ceiling, enable_short_term = true)
      [
        [S_MIN, INIT_S_MAX],           # w[0]: initial stability (Again)
        [S_MIN, INIT_S_MAX],           # w[1]: initial stability (Hard)
        [S_MIN, INIT_S_MAX],           # w[2]: initial stability (Good)
        [S_MIN, INIT_S_MAX],           # w[3]: initial stability (Easy)
        [1.0, 10.0],                   # w[4]: initial difficulty (Good)
        [0.001, 4.0],                  # w[5]: initial difficulty (multiplier)
        [0.001, 4.0],                  # w[6]: difficulty (multiplier)
        [0.001, 0.75],                 # w[7]: difficulty (multiplier)
        [0.0, 4.5],                    # w[8]: stability (exponent)
        [0.0, 0.8],                    # w[9]: stability (negative power)
        [0.001, 3.5],                  # w[10]: stability (exponent)
        [0.001, 5.0],                  # w[11]: fail stability (multiplier)
        [0.001, 0.25],                 # w[12]: fail stability (negative power)
        [0.001, 0.9],                  # w[13]: fail stability (power)
        [0.0, 4.0],                    # w[14]: fail stability (exponent)
        [0.0, 1.0],                    # w[15]: stability (multiplier for Hard)
        [1.0, 6.0],                    # w[16]: stability (multiplier for Easy)
        [0.0, w17_w18_ceiling],        # w[17]: short-term stability (exponent)
        [0.0, w17_w18_ceiling],        # w[18]: short-term stability (exponent)
        [enable_short_term ? 0.01 : 0.0, 0.8], # w[19]: short-term last-stability (exponent)
        [0.1, 0.8]                     # w[20]: decay
      ]
    end
  end
end
