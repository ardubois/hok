list_of_tuples = Map.put(%{}, "func",{:unit,[:float,:float]})
bytes = :erlang.term_to_binary(list_of_tuples)
File.write!("data.bin", bytes)

bytes = File.read!("data.bin")
list_of_tuples = :erlang.binary_to_term(bytes)

IO.inspect list_of_tuples
