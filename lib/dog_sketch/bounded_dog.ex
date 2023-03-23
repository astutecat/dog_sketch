defmodule DogSketch.BoundedDog do
  defstruct data: %{}, gamma: 0, total: 0, inv_log_gamma: 0, size: 0

  def new(opts \\ []) do
    err = Keyword.get(opts, :error, 0.02)
    size = Keyword.get(opts, :size, 2048)
    gamma = (1 + err) / (1 - err)
    inv_log_gamma = 1.0 / :math.log(gamma)
    %__MODULE__{gamma: gamma, inv_log_gamma: inv_log_gamma, size: size}
  end

  def merge(%{gamma: g} = s1, %{gamma: g} = s2) do
    data = Map.merge(s1.data, s2.data, fn _k, val1, val2 -> val1 + val2 end)
           |> collapse_buckets(s1.size)
    %__MODULE__{data: data, gamma: g, total: s1.total + s2.total}
  end

  def insert(s, val) when val > 0 do
    bin = ceil(:math.log(val) * s.inv_log_gamma)

    data = Map.update(s.data, bin, 1, fn x -> x + 1 end)
           |> collapse_buckets(s.size)

    %__MODULE__{s | data: data, total: s.total + 1}
  end

  def to_list(%{data: data, gamma: gamma}) do
    Enum.map(data, fn {key, val} ->
      {2 * :math.pow(gamma, key) / (gamma + 1), val}
    end)
  end

  def quantile(%{total: 0}, _), do: nil

  def quantile(s, quantile) when quantile >= 0 and quantile <= 1 do
    total_quantile = s.total * quantile

    index =
      Enum.sort_by(s.data, fn {key, _v} -> key end)
      |> Enum.reduce_while(0, fn {key, val}, total ->
        if total + val >= total_quantile do
          {:halt, key}
        else
          {:cont, total + val}
        end
      end)

    2 * :math.pow(s.gamma, index) / (s.gamma + 1)
  end

  def count(%{total: total}), do: total

  defp collapse_buckets(data, max), do: collapse_buckets(data, map_size(data), max)
  defp collapse_buckets(data, size, max) when size <= max, do: data
  defp collapse_buckets(data, size, max) do
    {left, right} = Enum.sort_by(data, fn {key, _v} -> key end)
                    |> Enum.split(size - max)
    sum = Enum.reduce(left, 0, fn({_key, v}, acc) -> v + acc end)
    [{key, val} | rest] = right
    Enum.into([{key, val + sum} | rest], %{})
  end
end
