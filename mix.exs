defmodule Rabbitex.Mixfile do
  use Mix.Project

  def project do
    [app: :rabbitex,
     version: "0.0.1",
     elixir: "~> 1.0.0",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [
                      :logger,
                      
                      :hashex,
                      :exutils,
                      :tinca,

                      :exrabbit,
                      :exactor,
                      :jazz

                    ],
     mod: {Rabbitex, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:hashex , github: "timCF/hashex"},
      {:exutils, github: "timCF/exutils"},
      {:tinca, github: "timCF/tinca"},

      {:exrabbit, github: "d0rc/exrabbit", branch: "rabbit-3.3"},
      {:exactor, github: "sasa1977/exactor"},
      {:jazz, github: "meh/jazz", override: true}
    ]
  end
end
