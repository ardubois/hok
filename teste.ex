defmodule MyModule do
  @after_compile __MODULE__

  def __after_compile__(env, _bytecode) do
    IO.inspect(env)
  end
end
