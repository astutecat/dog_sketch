defmodule BoundedDogSketchTest do
  use ExUnit.Case
  alias DogSketch.{BoundedDog, ExactDog}
  use PropCheck

  property "quantile within error bounds of exact" do
    forall {error, values, quantile} <-
             {float(0.0, 1.0), non_empty(list(non_neg_float())), float(0.0, 1.0)} do
      sd_quantile =
        Enum.reduce(values, BoundedDog.new(error: error, max_buckets: 2048), fn val, acc ->
          BoundedDog.insert(acc, val)
        end)
        |> BoundedDog.quantile(quantile)

      exact_quantile =
        Enum.reduce(values, ExactDog.new(), fn val, acc ->
          ExactDog.insert(acc, val)
        end)
        |> ExactDog.quantile(quantile)

      abs(sd_quantile / exact_quantile - 1) <= error
    end
  end

  property "merging is lossless" do
    forall {error, values, quantile} <-
             {float(0.0, 1.0), non_empty(list(non_neg_float())), float(0.0, 1.0)} do
      sd_quantile =
        Enum.reduce(values, BoundedDog.new(error: error, max_buckets: 2048), fn val, acc ->
          BoundedDog.insert(acc, val)
        end)
        |> BoundedDog.quantile(quantile)

      merged_quantile =
        Enum.reduce(values, BoundedDog.new(error: error), fn val, acc ->
          new_sd = BoundedDog.new(error: error) |> BoundedDog.insert(val)
          BoundedDog.merge(new_sd, acc)
        end)
        |> BoundedDog.quantile(quantile)

      sd_quantile == merged_quantile
    end
  end
end
