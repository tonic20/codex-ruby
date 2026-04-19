# frozen_string_literal: true

module CodexSDK
  # Serializes Ruby hashes into --config CLI flags using TOML value syntax.
  # Mirrors the TypeScript SDK's toTomlValue() and flattenConfig() logic.
  module ConfigSerializer
    BARE_KEY_PATTERN = /\A[A-Za-z0-9_-]+\z/

    module_function

    # Converts a nested hash into an array of ["--config", "key=value"] pairs.
    #
    #   to_flags({ sandbox_workspace_write: { network_access: true } })
    #   # => ["--config", "sandbox_workspace_write.network_access=true"]
    def to_flags(config)
      flatten(config).flat_map { |key, value| ["--config", "#{key}=#{to_toml_value(value)}"] }
    end

    # Flattens a nested hash into dotted key paths.
    #
    #   flatten({ a: { b: 1, c: { d: 2 } } })
    #   # => { "a.b" => 1, "a.c.d" => 2 }
    def flatten(hash, prefix: nil)
      hash.each_with_object({}) do |(key, value), result|
        full_key = prefix ? "#{prefix}.#{key}" : key.to_s
        if value.is_a?(Hash)
          result.merge!(flatten(value, prefix: full_key))
        else
          result[full_key] = value
        end
      end
    end

    # Converts a Ruby value to a TOML literal string.
    def to_toml_value(value)
      case value
      when String
        value.to_json
      when Integer, Float
        raise ArgumentError, "cannot serialize non-finite number" unless value.to_f.finite?

        value.to_s
      when true, false
        value.to_s
      when Array
        "[#{value.map { |v| to_toml_value(v) }.join(", ")}]"
      when Hash
        inner = value.map { |k, v| "#{format_key(k)} = #{to_toml_value(v)}" }.join(", ")
        "{#{inner}}"
      when nil
        raise ArgumentError, "cannot serialize nil to TOML"
      else
        raise ArgumentError, "unsupported type: #{value.class}"
      end
    end

    def format_key(key)
      str = key.to_s
      str.match?(BARE_KEY_PATTERN) ? str : str.to_json
    end
  end
end
