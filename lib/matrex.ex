defmodule Matrex do
  @moduledoc """
  Performs fast operations on matrices using native C code and CBLAS library.

  ## Access behaviour

  Access behaviour is partly implemented for Matrex, so you can do:

  ```elixir

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> m[2][3]
      7.0
  ```
  Or even:
  ```elixir

      iex> m[1..2]
      #Matrex[2×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      └                         ┘
  ```

  There are also several shortcuts for getting dimensions of matrix:
  ```elixir

      iex> m[:rows]
      3

      iex> m[:size]
      {3, 3}
  ```
  calculating maximum value of the whole matrix:
  ```elixir

      iex> m[:max]
      9.0
  ```
  or just one of it's rows:
  ```elixir

      iex> m[2][:max]
      7.0
  ```
  calculating one-based index of the maximum element for the whole matrix:
  ```elixir

      iex> m[:argmax]
      8
  ```
  and a row:
  ```elixir

      iex> m[2][:argmax]
      3
  ```
  ## Inspect protocol

  Matrex implements `Inspect` and looks nice in your console:

  ![Inspect Matrex](https://raw.githubusercontent.com/versilov/matrex/master/docs/matrex_inspect.png)

  ## Math operators overloading

  `Matrex.Operators` module redefines `Kernel` math operators (+, -, *, / <|>) and
  defines some convenience functions, so you can write calculations code in more natural way.

  It should be used with great caution. We suggest using it only inside specific functions
  and only for increased readability, because using `Matrex` module functions, especially
  ones which do two or more operations at one call, are 2-3 times faster.

  ### Example

  ```elixir

      def lr_cost_fun_ops(%Matrex{} = theta, {%Matrex{} = x, %Matrex{} = y, lambda} = _params)
          when is_number(lambda) do
        # Turn off original operators
        import Kernel, except: [-: 1, +: 2, -: 2, *: 2, /: 2, <|>: 2]
        import Matrex.Operators
        import Matrex

        m = y[:rows]

        h = sigmoid(x * theta)
        l = ones(size(theta)) |> set(1, 1, 0.0)

        j = (-t(y) * log(h) - t(1 - y) * log(1 - h) + lambda / 2 * t(l) * pow2(theta)) / m

        grad = (t(x) * (h - y) + (theta <|> l) * lambda) / m

        {scalar(j), grad}
      end
  ```


  The same function, coded with module methods calls (2.5 times faster):

  ```elixir
      def lr_cost_fun(%Matrex{} = theta, {%Matrex{} = x, %Matrex{} = y, lambda} = _params)
          when is_number(lambda) do
        m = y[:rows]

        h = Matrex.dot_and_apply(x, theta, :sigmoid)
        l = Matrex.ones(theta[:rows], theta[:cols]) |> Matrex.set(1, 1, 0)

        regularization =
          Matrex.dot_tn(l, Matrex.square(theta))
          |> Matrex.scalar()
          |> Kernel.*(lambda / (2 * m))

        j =
          y
          |> Matrex.dot_tn(Matrex.apply(h, :log), -1)
          |> Matrex.substract(
            Matrex.dot_tn(
              Matrex.substract(1, y),
              Matrex.apply(Matrex.substract(1, h), :log)
            )
          )
          |> Matrex.scalar()
          |> (fn
                NaN -> NaN
                x -> x / m + regularization
              end).()

        grad =
          x
          |> Matrex.dot_tn(Matrex.substract(h, y))
          |> Matrex.add(Matrex.multiply(theta, l), 1.0, lambda)
          |> Matrex.divide(m)

        {j, grad}
      end
  ```

  ## Enumerable protocol

  Matrex implements `Enumerable`, so, all kinds of `Enum` functions are applicable:

  ```elixir

      iex> Enum.member?(m, 2.0)
      true

      iex> Enum.count(m)
      9

      iex> Enum.sum(m)
      45
  ```

  For functions, that exist both in `Enum` and in `Matrex` it's preferred to use Matrex
  version, beacuse it's usually much, much faster. I.e., for 1 000 x 1 000 matrix `Matrex.sum/1`
  and `Matrex.to_list/1` are 438 and 41 times faster, respectively, than their `Enum` counterparts.

  ## Saving and loading matrix

  You can save/load matrix with native binary file format (extra fast)
  and CSV (slow, especially on large matrices).

  Matrex CSV format is compatible with GNU Octave CSV output,
  so you can use it to exchange data between two systems.

  ### Example

  ```elixir

      iex> Matrex.random(5) |> Matrex.save("rand.mtx")
      :ok
      iex> Matrex.load("rand.mtx")
      #Matrex[5×5]
      ┌                                         ┐
      │ 0.05624 0.78819 0.29995 0.25654 0.94082 │
      │ 0.50225 0.22923 0.31941  0.3329 0.78058 │
      │ 0.81769 0.66448 0.97414 0.08146 0.21654 │
      │ 0.33411 0.59648 0.24786 0.27596 0.09082 │
      │ 0.18673 0.18699 0.79753 0.08101 0.47516 │
      └                                         ┘
      iex> Matrex.magic(5) |> Matrex.divide(Matrex.eye(5)) |> Matrex.save("nan.csv")
      :ok
      iex> Matrex.load("nan.csv")
      #Matrex[5×5]
      ┌                                         ┐
      │    16.0     ∞       ∞       ∞       ∞   │
      │     ∞       4.0     ∞       ∞       ∞   │
      │     ∞       ∞      12.0     ∞       ∞   │
      │     ∞       ∞       ∞      25.0     ∞   │
      │     ∞       ∞       ∞       ∞       8.0 │
      └                                         ┘
  ```

  ## NaN and Infinity

  Float special values, like `NaN` and `Inf` live well inside matrices,
  can be loaded from and saved to files.
  But when getting them into Elixir they are transferred to `NaN`,`Inf` and `NegInf` atoms,
  because BEAM does not accept special values as valid floats.

  ```elixir
      iex> m = Matrex.eye(3)
      #Matrex[3×3]
      ┌                         ┐
      │     1.0     0.0     0.0 │
      │     0.0     1.0     0.0 │
      │     0.0     0.0     1.0 │
      └                         ┘

      iex> n = Matrex.divide(m, Matrex.zeros(3))
      #Matrex[3×3]
      ┌                         ┐
      │     ∞      NaN     NaN  │
      │    NaN      ∞      NaN  │
      │    NaN     NaN      ∞   │
      └                         ┘

      iex> n[1][1]
      Inf

      iex> n[1][2]
      NaN
  ```

  """

  alias Matrex.NIFs

  @enforce_keys [:data]
  defstruct [:data]
  @type element :: number | NaN | Inf | NegInf
  @type index :: pos_integer
  @type matrex :: %Matrex{data: binary}
  @type t :: matrex

  # Size of matrix element (float) in bytes
  @element_size 4

  # Float special values in binary form
  @not_a_number <<0, 0, 192, 255>>
  @positive_infinity <<0, 0, 128, 127>>
  @negative_infinity <<0, 0, 128, 255>>

  @compile {:inline,
            add: 2,
            argmax: 1,
            at: 3,
            binary_to_float: 1,
            column_to_list: 2,
            contains?: 2,
            divide: 2,
            dot: 2,
            dot_and_add: 3,
            dot_nt: 2,
            dot_tn: 2,
            eye: 1,
            element_to_string: 1,
            fill: 3,
            fill: 2,
            first: 1,
            fetch: 2,
            float_to_binary: 1,
            max: 1,
            multiply: 2,
            ones: 2,
            ones: 1,
            parse_float: 1,
            random: 2,
            random: 1,
            reshape: 3,
            row_to_list: 2,
            row: 2,
            set: 4,
            size: 1,
            square: 1,
            substract: 2,
            substract_inverse: 2,
            sum: 1,
            to_list: 1,
            to_list_of_lists: 1,
            transpose: 1,
            zeros: 2,
            zeros: 1}

  @behaviour Access

  # Horizontal vector
  @doc false
  @impl Access
  def fetch(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            _columns::unsigned-integer-little-32,
            _rest::binary
          >>
        } = matrex,
        key
      )
      when is_integer(key) and key > 0 and rows == 1,
      do: {:ok, at(matrex, 1, key)}

  # Vertical vector
  @impl Access
  def fetch(
        %Matrex{
          data: <<
            _rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            _rest::binary
          >>
        } = matrex,
        key
      )
      when is_integer(key) and key > 0 and columns == 1,
      do: {:ok, at(matrex, key, 1)}

  # Return a row
  @impl Access
  def fetch(
        %Matrex{} = matrex,
        key
      )
      when is_integer(key) and key > 0,
      do: {:ok, row(matrex, key)}

  @impl Access
  def fetch(
        %Matrex{
          data: <<
            1::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            data::binary
          >>
        },
        a..b
      )
      when b > a and a > 0 and b <= columns,
      do:
        {:ok,
         %Matrex{
           data:
             <<1::unsigned-integer-little-32, b - a + 1::unsigned-integer-little-32,
               binary_part(data, (a - 1) * @element_size, (b - a + 1) * @element_size)::binary>>
         }}

  @impl Access
  def fetch(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            data::binary
          >>
        },
        a..b
      )
      when b > a and a > 0 and b <= rows,
      do:
        {:ok,
         %Matrex{
           data:
             <<b - a + 1::unsigned-integer-little-32, columns::unsigned-integer-little-32,
               binary_part(
                 data,
                 (a - 1) * columns * @element_size,
                 (b - a + 1) * columns * @element_size
               )::binary>>
         }}

  @impl Access
  def fetch(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            _columns::unsigned-integer-little-32,
            _rest::binary
          >>
        },
        :rows
      ),
      do: {:ok, rows}

  @impl Access
  def fetch(
        %Matrex{
          data: <<
            _rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            _rest::binary
          >>
        },
        :cols
      ),
      do: {:ok, columns}

  @impl Access
  def fetch(
        %Matrex{
          data: <<
            _rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            _rest::binary
          >>
        },
        :columns
      ),
      do: {:ok, columns}

  @impl Access
  def fetch(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            _rest::binary
          >>
        },
        :size
      ),
      do: {:ok, {rows, columns}}

  @impl Access
  def fetch(%Matrex{} = matrex, :sum), do: {:ok, sum(matrex)}
  def fetch(%Matrex{} = matrex, :max), do: {:ok, max(matrex)}
  def fetch(%Matrex{} = matrex, :min), do: {:ok, min(matrex)}
  def fetch(%Matrex{} = matrex, :argmax), do: {:ok, argmax(matrex)}

  @doc false
  @impl Access
  def get(%Matrex{} = matrex, key, default) do
    case fetch(matrex, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @doc false
  @impl Access
  def pop(
        %Matrex{
          data:
            <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32,
              body::binary>>
        },
        row
      )
      when is_integer(row) and row >= 1 and row <= rows do
    {%Matrex{
       data:
         <<1::unsigned-integer-little-32, columns::unsigned-integer-little-32,
           binary_part(body, (row - 1) * columns * @element_size, columns * @element_size)::binary>>
     },
     %Matrex{
       data:
         <<rows - 1::unsigned-integer-little-32, columns::unsigned-integer-little-32,
           binary_part(body, 0, (row - 1) * columns * @element_size)::binary,
           binary_part(
             body,
             row * columns * @element_size,
             (rows - row) * columns * @element_size
           )::binary>>
     }}
  end

  def pop(%Matrex{} = matrex, _), do: {nil, matrex}

  # To silence warnings
  @doc false
  @impl Access
  def get_and_update(%Matrex{}, _row, _fun), do: :not_implemented

  defimpl Inspect do
    @doc false
    def inspect(%Matrex{} = matrex, %{width: screen_width}),
      do: Matrex.Inspect.do_inspect(matrex, screen_width)
  end

  defimpl Enumerable do
    # Matrix element size in bytes
    @element_size 4

    @doc false
    def count(%Matrex{
          data:
            <<rows::unsigned-integer-little-32, cols::unsigned-integer-little-32, _body::binary>>
        }),
        do: {:ok, rows * cols}

    @doc false
    def member?(%Matrex{} = matrex, element), do: {:ok, Matrex.contains?(matrex, element)}

    @doc false
    def slice(%Matrex{
          data:
            <<rows::unsigned-integer-little-32, cols::unsigned-integer-little-32, body::binary>>
        }),
        do:
          {:ok, rows * cols,
           fn start, length ->
             Matrex.binary_to_list(
               binary_part(body, start * @element_size, length * @element_size)
             )
           end}

    @doc false
    def reduce(
          %Matrex{
            data:
              <<_rows::unsigned-integer-little-32, _cols::unsigned-integer-little-32,
                body::binary>>
          },
          {:cont, acc},
          fun
        ),
        do: reduce(body, {:cont, acc}, fun)

    def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}

    def reduce(<<matrix::binary>>, {:suspend, acc}, fun),
      do: {:suspended, acc, &reduce(matrix, &1, fun)}

    def reduce(<<elem::binary-4, rest::binary>>, {:cont, acc}, fun),
      do: reduce(rest, fun.(Matrex.binary_to_float(elem), acc), fun)

    def reduce(<<>>, {:cont, acc}, _fun), do: {:done, acc}
  end

  @doc """
  Adds scalar to matrix.

  See `Matrex.add/4` for details.
  """
  @spec add(matrex, number) :: matrex
  @spec add(number, matrex) :: matrex
  def add(%Matrex{data: matrix} = _a, b) when is_number(b),
    do: %Matrex{data: NIFs.add_scalar(matrix, b)}

  def add(a, %Matrex{data: matrix} = _b) when is_number(a),
    do: %Matrex{data: NIFs.add_scalar(matrix, a)}

  @doc """
  Adds two matrices or scalar to each element of matrix. NIF.

  Can optionally scale any of the two matrices.

  C = αA + βB

  Raises `ErlangError` if matrices' sizes do not match.

  ## Examples

      iex> Matrex.add(Matrex.new([[1,2,3],[4,5,6]]), Matrex.new([[7,8,9],[10,11,12]]))
      #Matrex[2×3]
      ┌                         ┐
      │     8.0    10.0    12.0 │
      │    14.0    16.0    18.0 │
      └                         ┘

  Adding with scalar:

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> Matrex.add(m, 1)
      #Matrex[3×3]
      ┌                         ┐
      │     9.0     2.0     7.0 │
      │     4.0     6.0     8.0 │
      │     5.0    10.0     3.0 │
      └                         ┘

  With scaling each matrix:

      iex> Matrex.add(Matrex.new("1 2 3; 4 5 6"), Matrex.new("3 2 1; 6 5 4"), 2.0, 3.0)
      #Matrex[2×3]
      ┌                         ┐
      │     11.0    10.0    9.0 │
      │     26.0    25.0   24.0 │
      └                         ┘
  """

  @spec add(matrex, matrex, number, number) :: matrex
  def add(
        %Matrex{
          data:
            <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32,
              _data1::binary>> = first
        },
        %Matrex{
          data:
            <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32,
              _data2::binary>> = second
        },
        alpha \\ 1.0,
        beta \\ 1.0
      )
      when is_number(alpha) and is_number(beta),
      do: %Matrex{data: NIFs.add(first, second, alpha, beta)}

  @doc """

  Applies given function to each element of the matrix and returns the matrex of results.

  If second argument is an atom, then applies C language math function.
  NIF, multithreaded.

  Uses eight native threads, if matrix size is greater, than 100 000 elements.

  ## Example

      iex> Matrex.magic(5) |> Matrex.apply(:sigmoid)
      #Matrex[5×5]
      ┌                                         ┐
      │-0.95766-0.53283 0.28366  0.7539 0.13674 │
      │-0.99996-0.65364 0.96017 0.90745 0.40808 │
      │-0.98999-0.83907 0.84385  0.9887-0.54773 │
      │-0.91113 0.00443 0.66032  0.9912-0.41615 │
      │-0.75969-0.27516 0.42418  0.5403 -0.1455 │
      └                                         ┘

  The following math functions from C <math.h> are supported, and also a sigmoid function:

  ```elixir
    :exp, :exp2, :sigmoid, :expm1, :log, :log2, :sqrt, :cbrt, :ceil, :floor, :truncate, :round,
    :abs, :sin, :cos, :tan, :asin, :acos, :atan, :sinh, :cosh, :tanh, :asinh, :acosh, :atanh,
    :erf, :erfc, :tgamma, :lgamm
  ```


  If second argument is a function that takes one argument,
  then this function receives the element of the matrix.

  ## Example

      iex> Matrex.magic(5) |> Matrex.apply(&:math.cos/1)
      #Matrex[5×5]
      ┌                                         ┐
      │-0.95766-0.53283 0.28366  0.7539 0.13674 │
      │-0.99996-0.65364 0.96017 0.90745 0.40808 │
      │-0.98999-0.83907 0.84385  0.9887-0.54773 │
      │-0.91113 0.00443 0.66032  0.9912-0.41615 │
      │-0.75969-0.27516 0.42418  0.5403 -0.1455 │
      └                                         ┘


  If second argument is a function that takes two arguments,
  then this function receives the element of the matrix and its one-based index.


  ## Example

      iex> Matrex.ones(5) |> Matrex.apply(fn val, index -> val + index end)
      #Matrex[5×5]
      ┌                                         ┐
      │     2.0     3.0     4.0     5.0     6.0 │
      │     7.0     8.0     9.0    10.0    11.0 │
      │    12.0    13.0    14.0    15.0    16.0 │
      │    17.0    18.0    19.0    20.0    21.0 │
      │    22.0    23.0    24.0    25.0    26.0 │
      └                                         ┘

  If second argument is a function that takes three arguments,
  then this function receives the element of the matrix one-based row index and one-based
  column index of the element.

  ## Example

      iex> Matrex.ones(5) |> Matrex.apply(fn val, row, col -> val + row + col end)
      #Matrex[5×5]
      ┌                                         ┐
      │     3.0     4.0     5.0     6.0     7.0 │
      │     4.0     5.0     6.0     7.0     8.0 │
      │     5.0     6.0     7.0     8.0     9.0 │
      │     6.0     7.0     8.0     9.0    10.0 │
      │     7.0     8.0     9.0    10.0    11.0 │
      └                                         ┘

  """
  @math_functions [
    :exp,
    :exp2,
    :sigmoid,
    :expm1,
    :log,
    :log2,
    :sqrt,
    :cbrt,
    :ceil,
    :floor,
    :truncate,
    :round,
    :abs,
    :sin,
    :cos,
    :tan,
    :asin,
    :acos,
    :atan,
    :sinh,
    :cosh,
    :tanh,
    :asinh,
    :acosh,
    :atanh,
    :erf,
    :erfc,
    :tgamma,
    :lgamma
  ]

  @spec apply(
          matrex,
          atom
          | (element -> element)
          | (element, index -> element)
          | (element, index, index -> element)
        ) :: matrex
  def apply(%Matrex{data: data} = matrix, function_atom)
      when function_atom in @math_functions do
    {rows, cols} = size(matrix)

    %Matrex{
      data:
        if(
          rows * cols < 100_000,
          do: NIFs.apply_math(data, function_atom),
          else: NIFs.apply_parallel_math(data, function_atom)
        )
    }
  end

  def apply(
        %Matrex{
          data:
            <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32,
              data::binary>>
        },
        function
      )
      when is_function(function, 1) do
    initial = <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32>>

    %Matrex{data: apply_on_matrix(data, function, initial)}
  end

  def apply(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            data::binary
          >>
        },
        function
      )
      when is_function(function, 2) do
    initial = <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32>>
    size = rows * columns

    %Matrex{data: apply_on_matrix(data, function, 1, size, initial)}
  end

  def apply(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            data::binary
          >>
        },
        function
      )
      when is_function(function, 3) do
    initial = <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32>>

    %Matrex{data: apply_on_matrix(data, function, 1, 1, columns, initial)}
  end

  defp apply_on_matrix(<<>>, _, accumulator), do: accumulator

  defp apply_on_matrix(<<value::float-little-32, rest::binary>>, function, accumulator) do
    new_value = function.(value)

    apply_on_matrix(rest, function, <<accumulator::binary, new_value::float-little-32>>)
  end

  defp apply_on_matrix(<<>>, _, _, _, accumulator), do: accumulator

  defp apply_on_matrix(
         <<value::float-little-32, rest::binary>>,
         function,
         index,
         size,
         accumulator
       ) do
    new_value = function.(value, index)

    apply_on_matrix(
      rest,
      function,
      index + 1,
      size,
      <<accumulator::binary, new_value::float-little-32>>
    )
  end

  defp apply_on_matrix(<<>>, _, _, _, _, accumulator), do: accumulator

  defp apply_on_matrix(
         <<value::float-little-32, rest::binary>>,
         function,
         row_index,
         column_index,
         columns,
         accumulator
       ) do
    new_value = function.(value, row_index, column_index)
    new_accumulator = <<accumulator::binary, new_value::float-little-32>>

    case column_index < columns do
      true ->
        apply_on_matrix(rest, function, row_index, column_index + 1, columns, new_accumulator)

      false ->
        apply_on_matrix(rest, function, row_index + 1, 1, columns, new_accumulator)
    end
  end

  @doc """
  Applies function to elements of two matrices and returns matrix of function results.

  Matrices must be of the same size.

  ## Example

      iex(11)> Matrex.apply(Matrex.random(5), Matrex.random(5), fn x1, x2 -> min(x1, x2) end)
      #Matrex[5×5]
      ┌                                         ┐
      │ 0.02025 0.15055 0.69177 0.08159 0.07237 │
      │ 0.03252 0.14805 0.03627  0.1733 0.58721 │
      │ 0.10865 0.49192 0.12166  0.0573 0.66522 │
      │ 0.13642 0.23838 0.14403 0.57151 0.12359 │
      │ 0.12877 0.12745 0.10933 0.27281 0.35957 │
      └                                         ┘
  """
  @spec apply(matrex, matrex, (element, element -> element)) :: matrex
  def apply(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            first_data::binary
          >>
        },
        %Matrex{
          data: <<
            rows2::unsigned-integer-little-32,
            columns2::unsigned-integer-little-32,
            second_data::binary
          >>
        },
        function
      )
      when is_function(function, 2) and rows == rows2 and columns == columns2 do
    initial = <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32>>

    %Matrex{data: apply_on_matrices(first_data, second_data, function, initial)}
  end

  defp apply_on_matrices(<<>>, <<>>, _, accumulator), do: accumulator

  defp apply_on_matrices(
         <<first_value::float-little-32, first_rest::binary>>,
         <<second_value::float-little-32, second_rest::binary>>,
         function,
         accumulator
       )
       when is_function(function, 2) do
    new_value = function.(first_value, second_value)
    new_accumulator = <<accumulator::binary, new_value::float-little-32>>

    apply_on_matrices(first_rest, second_rest, function, new_accumulator)
  end

  @doc """
  Returns one-based index of the biggest element. NIF.

  There is also `matrex[:argmax]` shortcut for this function.

  ## Example

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> Matrex.argmax(m)
      7

  """
  @spec argmax(matrex) :: index
  def argmax(%Matrex{data: data}), do: NIFs.argmax(data) + 1

  @doc """
  Get element of a matrix at given one-based (row, column) position.

  ## Example

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> Matrex.at(m, 3, 2)
      9.0

  You can use `Access` behaviour square brackets for the same purpose,
  but it will be slower:

      iex> m[3][2]
      9.0

  """
  @spec at(matrex, index, index) :: element
  def at(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            data::binary
          >>
        },
        row,
        col
      )
      when is_integer(row) and is_integer(col) do
    if row < 1 or row > rows,
      do: raise(ArgumentError, message: "Row position out of range: #{row}")

    if col < 1 or col > columns,
      do: raise(ArgumentError, message: "Column position out of range: #{col}")

    data
    |> binary_part(((row - 1) * columns + (col - 1)) * @element_size, @element_size)
    |> binary_to_float()
  end

  @doc false
  @spec binary_to_float(<<_::32>>) :: element | NaN | Inf | NegInf
  def binary_to_float(@not_a_number), do: NaN
  def binary_to_float(@positive_infinity), do: Inf
  def binary_to_float(@negative_infinity), do: NegInf
  def binary_to_float(<<val::float-little-32>>), do: val

  @doc false
  def binary_to_list(<<elem::binary-4, rest::binary>>),
    do: [binary_to_float(elem) | binary_to_list(rest)]

  def binary_to_list(<<>>), do: []

  @doc """
  Get column of matrix as matrix (vector) in matrex form. One-based.

  ## Example

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> Matrex.column(m, 2)
      #Matrex[3×1]
      ┌         ┐
      │     1.0 │
      │     5.0 │
      │     9.0 │
      └         ┘

  """
  @spec column(matrex, index) :: matrex
  def column(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            data::binary
          >>
        },
        col
      )
      when is_integer(col) and col > 0 and col <= columns do
    column = <<rows::unsigned-integer-little-32, 1::unsigned-integer-little-32>>

    %Matrex{
      data:
        0..(rows - 1)
        |> Enum.reduce(column, fn row, acc ->
          <<acc::binary,
            binary_part(data, (row * columns + (col - 1)) * @element_size, @element_size)::binary>>
        end)
    }
  end

  @doc """
  Get column of matrix as list of floats. One-based, NIF.


  ## Example

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> Matrex.column_to_list(m, 3)
      [6.0, 7.0, 2.0]

  """
  @spec column_to_list(matrex, index) :: [element]
  def column_to_list(%Matrex{data: matrix}, column) when is_integer(column) and column > 0,
    do: NIFs.column_to_list(matrix, column - 1)

  @doc """
  Concatenate list of matrices along columns.

  The number of rows must be equal.

  ## Example

      iex> Matrex.concat([Matrex.fill(2, 0), Matrex.fill(2, 1), Matrex.fill(2, 2)])                #Matrex[2×6]
      ┌                                                 ┐
      │     0.0     0.0     1.0     1.0     2.0     2.0 │
      │     0.0     0.0     1.0     1.0     2.0     2.0 │
      └                                                 ┘

  """
  @spec concat([matrex]) :: matrex
  def concat([%Matrex{} | _] = list_of_ma), do: Enum.reduce(list_of_ma, &Matrex.concat(&2, &1))

  @doc """
  Concatenate two matrices along rows or columns. NIF.

  The number of rows or columns must be equal.

  ## Examples

      iex> m1 = Matrex.new([[1, 2, 3], [4, 5, 6]])
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      └                         ┘
      iex> m2 = Matrex.new([[7, 8, 9], [10, 11, 12]])
      #Matrex[2×3]
      ┌                         ┐
      │     7.0     8.0     9.0 │
      │    10.0    11.0    12.0 │
      └                         ┘
      iex> Matrex.concat(m1, m2)
      #Matrex[2×6]
      ┌                                                 ┐
      │     1.0     2.0     3.0     7.0     8.0     9.0 │
      │     4.0     5.0     6.0    10.0    11.0    12.0 │
      └                                                 ┘
      iex> Matrex.concat(m1, m2, :rows)
      #Matrex[4×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      │     7.0     8.0     9.0 │
      │    10.0    11.0    12.0 │
      └                         ┘
  """
  @spec concat(matrex, matrex, :columns | :rows) :: matrex
  def concat(matrex1, matrex2, type \\ :columns)

  def concat(
        %Matrex{
          data:
            <<
              rows1::unsigned-integer-little-32,
              columns1::unsigned-integer-little-32,
              data1::binary
            >> = first
        },
        %Matrex{
          data:
            <<
              rows2::unsigned-integer-little-32,
              columns2::unsigned-integer-little-32,
              data2::binary
            >> = second
        },
        :columns
      )
      when rows1 == rows2 do
    %Matrex{data: Matrex.NIFs.concat_columns(first, second)}
    #   initial =
    #     <<rows1::unsigned-integer-little-32, columns1 + columns2::unsigned-integer-little-32>>
    #
    #   %Matrex{data: do_concat(initial, data1, columns1, data2, columns2)}
  end

  def concat(
        %Matrex{
          data: <<
            rows1::unsigned-integer-little-32,
            columns1::unsigned-integer-little-32,
            data1::binary
          >>
        },
        %Matrex{
          data: <<
            rows2::unsigned-integer-little-32,
            columns2::unsigned-integer-little-32,
            data2::binary
          >>
        },
        :rows
      )
      when columns1 == columns2 do
    %Matrex{
      data:
        <<rows1 + rows2::unsigned-integer-little-32, columns1::unsigned-integer-little-32,
          data1::binary, data2::binary>>
    }
  end

  def concat(
        %Matrex{
          data: <<
            rows1::unsigned-integer-little-32,
            columns1::unsigned-integer-little-32,
            _data1::binary
          >>
        },
        %Matrex{
          data: <<
            rows2::unsigned-integer-little-32,
            columns2::unsigned-integer-little-32,
            _data2::binary
          >>
        },
        type
      ),
      do:
        raise(
          ArgumentError,
          message:
            "Cannot concat: #{rows1}×#{columns1} does not fit with #{rows2}×#{columns2} along #{
              type
            }."
        )

  defp do_concat(result, <<>>, _, <<>>, _), do: result

  defp do_concat(
         result,
         data1,
         columns1,
         data2,
         columns2
       ) do
    row1 = binary_part(data1, 0, columns1 * @element_size)

    rest1 =
      binary_part(data1, columns1 * @element_size, byte_size(data1) - columns1 * @element_size)

    row2 = binary_part(data2, 0, columns2 * @element_size)

    rest2 =
      binary_part(data2, columns2 * @element_size, byte_size(data2) - columns2 * @element_size)

    do_concat(<<result::binary, row1::binary, row2::binary>>, rest1, columns1, rest2, columns2)
  end

  @doc """
  Checks if given element exists in the matrix.

  ## Example

      iex> m = Matrex.new("1 NaN 3; Inf 10 23")
      #Matrex[2×3]
      ┌                         ┐
      │     1.0    NaN      3.0 │
      │     ∞      10.0    23.0 │
      └                         ┘
      iex> Matrex.contains?(m, 1.0)
      true
      iex> Matrex.contains?(m, NaN)
      true
      iex> Matrex.contains?(m, 9)
      false
  """
  @spec contains?(matrex, element) :: boolean
  def contains?(%Matrex{} = matrex, value), do: find(matrex, value) != nil

  @doc """
  Divides two matrices element-wise or matrix by scalar or scalar by matrix. NIF through `find/2`.

  Raises `ErlangError` if matrices' sizes do not match.

  ## Examples

      iex> Matrex.new([[10, 20, 25], [8, 9, 4]])
      ...> |> Matrex.divide(Matrex.new([[5, 10, 5], [4, 3, 4]]))
      #Matrex[2×3]
      ┌                         ┐
      │     2.0     2.0     5.0 │
      │     2.0     3.0     1.0 │
      └                         ┘

      iex> Matrex.new([[10, 20, 25], [8, 9, 4]])
      ...> |> Matrex.divide(2)
      #Matrex[2×3]
      ┌                         ┐
      │     5.0    10.0    12.5 │
      │     4.0     4.5     2.0 │
      └                         ┘

      iex> Matrex.divide(100, Matrex.new([[10, 20, 25], [8, 16, 4]]))
      #Matrex[2×3]
      ┌                         ┐
      │    10.0     5.0     4.0 │
      │    12.5    6.25    25.0 │
      └                         ┘

  """
  @spec divide(matrex, matrex) :: matrex
  @spec divide(matrex, number) :: matrex
  @spec divide(number, matrex) :: matrex
  def divide(%Matrex{data: dividend} = _dividend, %Matrex{data: divisor} = _divisor),
    do: %Matrex{data: NIFs.divide(dividend, divisor)}

  def divide(%Matrex{data: matrix}, scalar) when is_number(scalar),
    do: %Matrex{data: NIFs.divide_by_scalar(matrix, scalar)}

  def divide(scalar, %Matrex{data: matrix}) when is_number(scalar),
    do: %Matrex{data: NIFs.divide_scalar(scalar, matrix)}

  @doc """
  Matrix multiplication. NIF, via `cblas_sgemm()`.

  Number of columns of the first matrix must be equal to the number of rows of the second matrix.

  Raises `ErlangError` if matrices' sizes do not match.

  ## Example

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]]) |>
      ...> Matrex.dot(Matrex.new([[1, 2], [3, 4], [5, 6]]))
      #Matrex[2×2]
      ┌                 ┐
      │    22.0    28.0 │
      │    49.0    64.0 │
      └                 ┘

  """
  @spec dot(matrex, matrex) :: matrex
  def dot(
        %Matrex{
          data:
            <<
              _rows1::unsigned-integer-little-32,
              columns1::unsigned-integer-little-32,
              _data1::binary
            >> = first
        },
        %Matrex{
          data:
            <<
              rows2::unsigned-integer-little-32,
              _columns2::unsigned-integer-little-32,
              _data2::binary
            >> = second
        }
      )
      when columns1 == rows2,
      do: %Matrex{data: NIFs.dot(first, second)}

  @doc """
  Matrix multiplication with addition of third matrix.  NIF, via `cblas_sgemm()`.

  Raises `ErlangError` if matrices' sizes do not match.

  ## Example

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]]) |>
      ...> Matrex.dot_and_add(Matrex.new([[1, 2], [3, 4], [5, 6]]), Matrex.new([[1, 2], [3, 4]]))
      #Matrex[2×2]
      ┌                 ┐
      │    23.0    30.0 │
      │    52.0    68.0 │
      └                 ┘

  """
  @spec dot_and_add(matrex, matrex, matrex) :: matrex
  def dot_and_add(
        %Matrex{
          data:
            <<
              _rows1::unsigned-integer-little-32,
              columns1::unsigned-integer-little-32,
              _data1::binary
            >> = first
        },
        %Matrex{
          data:
            <<
              rows2::unsigned-integer-little-32,
              _columns2::unsigned-integer-little-32,
              _data2::binary
            >> = second
        },
        %Matrex{data: third}
      )
      when columns1 == rows2,
      do: %Matrex{data: NIFs.dot_and_add(first, second, third)}

  @doc """
  Computes dot product of two matrices, then applies math function to each element
  of the resulting matrix.

  ## Example

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]]) |>
      ...> Matrex.dot_and_add(Matrex.new([[1, 2], [3, 4], [5, 6]]), :sqrt)
      #Matrex[2×2]
      ┌                 ┐
      │ 4.69042  5.2915 │
      │     7.0     8.0 │
      └                 ┘
  """
  @spec dot_and_apply(matrex, matrex, atom) :: matrex
  def dot_and_apply(
        %Matrex{
          data:
            <<
              _rows1::unsigned-integer-little-32,
              columns1::unsigned-integer-little-32,
              _data1::binary
            >> = first
        },
        %Matrex{
          data:
            <<
              rows2::unsigned-integer-little-32,
              _columns2::unsigned-integer-little-32,
              _data2::binary
            >> = second
        },
        function
      )
      when columns1 == rows2 and function in @math_functions,
      do: %Matrex{data: NIFs.dot_and_apply(first, second, function)}

  @doc """
  Matrix multiplication where the second matrix needs to be transposed.  NIF, via `cblas_sgemm()`.

  Raises `ErlangError` if matrices' sizes do not match.

  ## Example

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]]) |>
      ...> Matrex.dot_nt(Matrex.new([[1, 3, 5], [2, 4, 6]]))
      #Matrex[2×2]
      ┌                 ┐
      │    22.0    28.0 │
      │    49.0    64.0 │
      └                 ┘

  """
  @spec dot_nt(matrex, matrex) :: matrex
  def dot_nt(
        %Matrex{
          data:
            <<
              _rows1::unsigned-integer-little-32,
              columns1::unsigned-integer-little-32,
              _data1::binary
            >> = first
        },
        %Matrex{
          data:
            <<
              _rows2::unsigned-integer-little-32,
              columns2::unsigned-integer-little-32,
              _data2::binary
            >> = second
        }
      )
      when columns1 == columns2,
      do: %Matrex{data: NIFs.dot_nt(first, second)}

  @doc """
  Matrix dot multiplication where the first matrix needs to be transposed.  NIF, via `cblas_sgemm()`.

  The result is multiplied by scalar `alpha`.

  Raises `ErlangError` if matrices' sizes do not match.

  ## Example

      iex> Matrex.new([[1, 4], [2, 5], [3, 6]]) |>
      ...> Matrex.dot_tn(Matrex.new([[1, 2], [3, 4], [5, 6]]))
      #Matrex[2×2]
      ┌                 ┐
      │    22.0    28.0 │
      │    49.0    64.0 │
      └                 ┘

  """
  @spec dot_tn(matrex, matrex, number) :: matrex
  def dot_tn(
        %Matrex{
          data:
            <<
              rows1::unsigned-integer-little-32,
              _columns1::unsigned-integer-little-32,
              _data1::binary
            >> = first
        },
        %Matrex{
          data:
            <<
              rows2::unsigned-integer-little-32,
              _columns2::unsigned-integer-little-32,
              _data2::binary
            >> = second
        },
        alpha \\ 1.0
      )
      when rows1 == rows2 and is_number(alpha),
      do: %Matrex{data: NIFs.dot_tn(first, second, alpha)}

  @doc """
  Create eye (identity) square matrix of given size.

  ## Examples

      iex> Matrex.eye(3)
      #Matrex[3×3]
      ┌                         ┐
      │     1.0     0.0     0.0 │
      │     0.0     1.0     0.0 │
      │     0.0     0.0     1.0 │
      └                         ┘

      iex> Matrex.eye(3, 2.95)
      #Matrex[3×3]
      ┌                         ┐
      │    2.95     0.0     0.0 │
      │     0.0    2.95     0.0 │
      │     0.0     0.0    2.95 │
      └                         ┘
  """
  @spec eye(index, element) :: matrex
  def eye(size, value \\ 1.0) when is_integer(size) and is_number(value),
    do: %Matrex{data: NIFs.eye(size, value)}

  @doc """
  Create matrix filled with given value. NIF.

  ## Example

      iex> Matrex.fill(4,3, 55)
      #Matrex[4×3]
      ┌                         ┐
      │    55.0    55.0    55.0 │
      │    55.0    55.0    55.0 │
      │    55.0    55.0    55.0 │
      │    55.0    55.0    55.0 │
      └                         ┘
  """
  @spec fill(index, index, number) :: matrex
  def fill(rows, cols, value)
      when is_integer(rows) and is_integer(cols) and is_number(value),
      do: %Matrex{data: NIFs.fill(rows, cols, value)}

  @doc """
  Create square matrix filled with given value. Inlined.

  ## Example

      iex> Matrex.fill(3, 55)
      #Matrex[3×3]
      ┌                         ┐
      │    33.0    33.0    33.0 │
      │    33.0    33.0    33.0 │
      │    33.0    33.0    33.0 │
      └                         ┘
  """
  @spec fill(index, number) :: matrex
  def fill(size, value), do: fill(size, size, value)

  @doc """
  Find position of the first occurence of the given value in the matrix. NIF.

  Returns {row, column} tuple or nil, if nothing was found. One-based.

  ## Example


  """
  @spec find(matrex, element) :: {index, index} | nil
  def find(%Matrex{data: data}, value) when is_number(value) or value in [NaN, Inf, PosInf],
    do: NIFs.find(data, float_to_binary(value))

  @doc """
  Return first element of a matrix.

  ## Example

      iex> Matrex.new([[6,5,4],[3,2,1]]) |> Matrex.first()
      6.0

  """
  @spec first(matrex) :: element | NaN | Inf | NegInf
  def first(%Matrex{
        data: <<
          _rows::unsigned-integer-little-32,
          _columns::unsigned-integer-little-32,
          element::binary-4,
          _rest::binary
        >>
      }),
      do: binary_to_float(element)

  @doc """
  Prints monochrome or color heatmap of the matrix to the console.

  Only on terminals, that support 24bit color. E.g., iTerm2 on MacOS.

  ## Examples

  <img src="https://raw.githubusercontent.com/versilov/matrex/master/docs/logistic_regression.gif" width="215px" />&nbsp;
  <img src="https://raw.githubusercontent.com/versilov/matrex/master/docs/mnist8.png" width="200px" />&nbsp;
  <img src="https://raw.githubusercontent.com/versilov/matrex/master/docs/magic_square.png" width="200px" />&nbsp;
  <img src="https://raw.githubusercontent.com/versilov/matrex/master/docs/hot_boobs.png" width="220px"  />&nbsp;
  <img src="https://raw.githubusercontent.com/versilov/matrex/master/docs/neurons_mono.png" width="233px"  />

  """
  @spec heatmap(matrex, :mono8 | :color8 | :mono256 | :color256 | :mono24bit | :color24bit) ::
          matrex
  defdelegate heatmap(matrex, type \\ :mono256), to: Matrex.Inspect

  @doc """
  An alias for `eye/1`.
  """
  @spec identity(index) :: matrex
  defdelegate identity(size), to: __MODULE__, as: :eye

  @doc """
  Displays a visualization of the matrix.

  Set the second parameter to true to show full numbers.
  Otherwise, they are truncated.

  """
  @spec inspect(matrex, boolean) :: matrex
  def inspect(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            rest::binary
          >>
        } = matrex,
        full \\ false
      ) do
    IO.puts("Rows: #{rows} Columns: #{columns}")

    inspect_element(1, columns, rest, full)

    matrex
  end

  defp inspect_element(_, _, <<>>, _), do: :ok

  defp inspect_element(column, columns, <<element::float-little-32, rest::binary>>, full) do
    next_column =
      case column == columns do
        true ->
          IO.puts(undot(element, full))

          1.0

        false ->
          IO.write("#{undot(element, full)} ")

          column + 1.0
      end

    inspect_element(next_column, columns, rest, full)
  end

  defp undot(f, false) when is_float(f) and f - trunc(f) == 0.0, do: trunc(f)
  defp undot(f, false) when is_float(f), do: :io_lib.format("~7.3f", [f])
  defp undot(f, true) when is_float(f), do: f

  @doc """
  Load matrex from file.

  .csv and .mtx (binary) formats are supported.

  ## Example

      iex> Matrex.load("test/matrex.csv")
      #Matrex[5×4]
      ┌                                 ┐
      │     0.0  4.8e-4-0.00517-0.01552 │
      │-0.01616-0.01622 -0.0161-0.00574 │
      │  6.8e-4     0.0     0.0     0.0 │
      │     0.0     0.0     0.0     0.0 │
      │     0.0     0.0     0.0     0.0 │
      └                                 ┘
  """
  @spec load(binary) :: matrex
  def load(file_name) when is_binary(file_name) do
    cond do
      :filename.extension(file_name) == ".gz" ->
        File.read!(file_name)
        |> :zlib.gunzip()
        |> do_load(String.split(file_name, ".") |> Enum.at(-2))

      :filename.extension(file_name) == ".csv" ->
        do_load(File.read!(file_name), "csv")

      :filename.extension(file_name) == ".mtx" ->
        do_load(File.read!(file_name), "mtx")

      :filename.extension(file_name) == ".idx" ->
        do_load(File.read!(file_name), "idx")

      true ->
        raise "Unknown file format: #{file_name}"
    end
  end

  defp do_load(data, "csv"), do: new(data)
  defp do_load(data, "mtx"), do: %Matrex{data: data}
  defp do_load(data, "idx"), do: %Matrex{data: Matrex.IDX.load(data)}

  @doc """
  Creates "magic" n*n matrix, where sums of all dimensions are equal


  ## Example

      iex> Matrex.magic(5)
      #Matrex[5×5]
      ┌                                         ┐
      │    16.0    23.0     5.0     7.0    14.0 │
      │    22.0     4.0     6.0    13.0    20.0 │
      │     3.0    10.0    12.0    19.0    21.0 │
      │     9.0    11.0    18.0    25.0     2.0 │
      │    15.0    17.0    24.0     1.0     8.0 │
      └                                         ┘
  """
  @spec magic(index) :: matrex
  def magic(n) when is_integer(n), do: Matrex.MagicSquare.new(n) |> new()

  @doc false
  # Shortcut to get functions list outside in Matrex.Operators module.
  def math_functions_list(), do: @math_functions

  @doc """
  Maximum element in a matrix. NIF.

  ## Example

      iex> m = Matrex.magic(5)
      #Matrex[5×5]
      ┌                                         ┐
      │    16.0    23.0     5.0     7.0    14.0 │
      │    22.0     4.0     6.0    13.0    20.0 │
      │     3.0    10.0    12.0    19.0    21.0 │
      │     9.0    11.0    18.0    25.0     2.0 │
      │    15.0    17.0    24.0     1.0     8.0 │
      └                                         ┘
      iex> Matrex.max(m)
      25.0

  """
  @spec max(matrex) :: element
  def max(%Matrex{data: matrix}), do: NIFs.max(matrix)

  @doc """

  Minimum element in a matrix. NIF.

  ## Example

      iex> m = Matrex.magic(5)
      #Matrex[5×5]
      ┌                                         ┐
      │    16.0    23.0     5.0     7.0    14.0 │
      │    22.0     4.0     6.0    13.0    20.0 │
      │     3.0    10.0    12.0    19.0    21.0 │
      │     9.0    11.0    18.0    25.0     2.0 │
      │    15.0    17.0    24.0     1.0     8.0 │
      └                                         ┘
      iex> Matrex.min(m)
      1.0

  """
  @spec min(matrex) :: element
  def min(%Matrex{data: matrix}), do: NIFs.min(matrix)

  @doc """
  Elementwise multiplication of two matrices or matrix and a scalar. NIF.

  Raises `ErlangError` if matrices' sizes do not match.

  ## Examples

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]]) |>
      ...> Matrex.multiply(Matrex.new([[5, 2, 1], [3, 4, 6]]))
      #Matrex[2×3]
      ┌                         ┐
      │     5.0     4.0     3.0 │
      │    12.0    20.0    36.0 │
      └                         ┘

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]]) |> Matrex.multiply(2)
      #Matrex[2×3]
      ┌                         ┐
      │     2.0     4.0     6.0 │
      │     8.0    10.0    12.0 │
      └                         ┘

  """
  @spec multiply(matrex, matrex) :: matrex
  @spec multiply(matrex, number) :: matrex
  @spec multiply(number, matrex) :: matrex
  def multiply(%Matrex{data: first}, %Matrex{data: second}),
    do: %Matrex{data: NIFs.multiply(first, second)}

  def multiply(%Matrex{data: matrix}, scalar) when is_number(scalar),
    do: %Matrex{data: NIFs.multiply_with_scalar(matrix, scalar)}

  def multiply(scalar, %Matrex{data: matrix}) when is_number(scalar),
    do: %Matrex{data: NIFs.multiply_with_scalar(matrix, scalar)}

  @doc """
  Negates each element of the matrix. NIF.

  ## Example

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]]) |> Matrex.neg()
      #Matrex[2×3]
      ┌                         ┐
      │    -1.0    -2.0    -3.0 │
      │    -4.0    -5.0    -6.0 │
      └                         ┘

  """
  @spec neg(matrex) :: matrex
  def neg(%Matrex{data: matrix}), do: %Matrex{data: NIFs.neg(matrix)}

  @doc """
  Creates new matrix with values provided by the given function.

  If function accepts two arguments one-based row and column of each element are passed to it.

  ## Examples

      iex> Matrex.new(3, 3, fn -> :rand.uniform() end)
      #Matrex[3×3]
      ┌                         ┐
      │ 0.45643 0.91533 0.25332 │
      │ 0.29095 0.21241  0.9776 │
      │ 0.42451 0.05422 0.92863 │
      └                         ┘

      iex> Matrex.new(3, 3, fn row, col -> row*col end)
      #Matrex[3×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     2.0     4.0     6.0 │
      │     3.0     6.0     9.0 │
      └                         ┘

  """
  @spec new(index, index, (() -> element)) :: matrex
  @spec new(index, index, (index, index -> element)) :: matrex
  def new(rows, columns, function) when is_function(function, 0) do
    initial = <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32>>

    new_matrix_from_function(rows * columns, function, initial)
  end

  def new(rows, columns, function) when is_function(function, 2) do
    initial = <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32>>
    size = rows * columns

    new_matrix_from_function(size, rows, columns, function, initial)
  end

  @spec float_to_binary(element | NaN | Inf | NegInf) :: binary
  defp float_to_binary(val) when is_number(val), do: <<val::float-little-32>>
  defp float_to_binary(NaN), do: @not_a_number
  defp float_to_binary(Inf), do: @positive_infinity
  defp float_to_binary(NegInf), do: @negative_infinity

  @doc """
  Creates new matrix from list of lists or text representation (compatible with MathLab/Octave).

  List of lists can contain other matrices, which are concatenated in one.

  ## Example

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]])
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      └                         ┘

      iex> Matrex.new([[Matrex.fill(2, 1.0), Matrex.fill(2, 3, 2.0)],
      ...> [Matrex.fill(1, 2, 3.0), Matrex.fill(1, 3, 4.0)]])
      #Matrex[5×5]
      ┌                                         ┐
      │     1.0     1.0     2.0     2.0     2.0 │
      │     1.0     1.0     2.0     2.0     2.0 │
      │     3.0     3.0     4.0     4.0     4.0 │
      └                                         ┘

      iex> Matrex.new("1;0;1;0;1")
      #Matrex[5×1]
      ┌         ┐
      │     1.0 │
      │     0.0 │
      │     1.0 │
      │     0.0 │
      │     1.0 │
      └         ┘

      iex> Matrex.new(\"\"\"
      ...>         1.00000   0.10000   0.60000   1.10000
      ...>         1.00000   0.20000   0.70000   1.20000
      ...>         1.00000       NaN   0.80000   1.30000
      ...>             Inf   0.40000   0.90000   1.40000
      ...>         1.00000   0.50000    NegInf   1.50000
      ...>       \"\"\")
      #Matrex[5×4]
      ┌                                 ┐
      │     1.0     0.1     0.6     1.1 │
      │     1.0     0.2     0.7     1.2 │
      │     1.0    NaN      0.8     1.3 │
      │     ∞       0.4     0.9     1.4 │
      │     1.0     0.5    -∞       1.5 │
      └                                 ┘

  """
  @spec new([[element]] | [[matrex]] | binary) :: matrex
  def new(
        [
          [
            %Matrex{} | _
          ]
          | _
        ] = lol_of_ma
      ) do
    lol_of_ma
    |> Enum.map(&Matrex.concat/1)
    |> Enum.reduce(&Matrex.concat(&2, &1, :rows))
  end

  def new([first_list | _] = lol_or_binary) when is_list(first_list) do
    rows = length(lol_or_binary)
    columns = length(first_list)

    initial = <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32>>

    %Matrex{
      data:
        Enum.reduce(lol_or_binary, initial, fn list, accumulator ->
          accumulator <>
            Enum.reduce(list, <<>>, fn element, partial ->
              <<partial::binary, float_to_binary(element)::binary>>
            end)
        end)
    }
  end

  def new(text) when is_binary(text) do
    text
    |> String.split(["\n", ";"], trim: true)
    |> Enum.map(fn line ->
      line
      |> String.split(["\s", ","], trim: true)
      |> Enum.map(fn f -> parse_float(f) end)
    end)
    |> new()
  end

  @spec parse_float(binary) :: element | NaN | Inf | NegInf
  defp parse_float("NaN"), do: NaN
  defp parse_float("Inf"), do: Inf
  defp parse_float("-Inf"), do: NegInf
  defp parse_float("NegInf"), do: NegInf
  defp parse_float(string), do: Float.parse(string) |> elem(0)

  defp new_matrix_from_function(0, _, accumulator), do: %Matrex{data: accumulator}

  defp new_matrix_from_function(size, function, accumulator),
    do:
      new_matrix_from_function(
        size - 1,
        function,
        <<accumulator::binary, function.()::float-little-32>>
      )

  defp new_matrix_from_function(0, _, _, _, accumulator), do: %Matrex{data: accumulator}

  defp new_matrix_from_function(size, rows, columns, function, accumulator) do
    {row, col} =
      if rem(size, columns) == 0 do
        {rows - div(size, columns), 0}
      else
        {rows - 1 - div(size, columns), columns - rem(size, columns)}
      end

    new_accumulator = <<accumulator::binary, function.(row + 1, col + 1)::float-little-32>>

    new_matrix_from_function(size - 1, rows, columns, function, new_accumulator)
  end

  @doc """
  Bring all values of matrix into [0, 1] range. NIF.

  Where 0 corresponds to the minimum value of the matrix, and 1 — to the maxixmim.

  ## Example

      iex> m = Matrex.reshape(1..9, 3, 3)
      #Matrex[3×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      │     7.0     8.0     9.0 │
      └                         ┘
      iex> Matrex.normalize(m)
      #Matrex[3×3]
      ┌                         ┐
      │     0.0   0.125    0.25 │
      │   0.375     0.5   0.625 │
      │    0.75   0.875     1.0 │
      └                         ┘
  """
  @spec normalize(matrex) :: matrex
  def normalize(%Matrex{data: data}), do: %Matrex{data: NIFs.normalize(data)}

  @doc """
  Create matrix filled with ones.

  ## Example

      iex> Matrex.ones(2, 3)
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     1.0     1.0 │
      │     1.0     1.0     1.0 │
      └                         ┘
  """
  @spec ones(index, index) :: matrex
  def ones(rows, cols) when is_integer(rows) and is_integer(cols), do: fill(rows, cols, 1)

  @doc """
  Create matrex of ones of square dimensions or consuming output of `size/1` function.

  ## Examples

      iex> Matrex.ones(3)
      #Matrex[3×3]
      ┌                         ┐
      │     1.0     1.0     1.0 │
      │     1.0     1.0     1.0 │
      │     1.0     1.0     1.0 │
      └                         ┘

      iex> m = Matrex.new("1 2 3; 4 5 6")
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      └                         ┘
      iex> Matrex.ones(Matrex.size(m))
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     1.0     1.0 │
      │     1.0     1.0     1.0 │
      └                         ┘
  """
  @spec ones(index) :: matrex
  @spec ones({index, index}) :: matrex
  def ones({rows, cols}), do: ones(rows, cols)

  def ones(size) when is_integer(size), do: fill(size, 1)

  @doc """
  Create matrix of random floats in [0, 1] range. NIF.

  C language RNG is seeded on NIF libray load with `srandom(time(NULL) + clock())`.

  ## Example

      iex> Matrex.random(4,3)
      #Matrex[4×3]
      ┌                         ┐
      │ 0.32994 0.28736 0.88012 │
      │ 0.51782 0.68608 0.29976 │
      │ 0.52953  0.9071 0.26743 │
      │ 0.82189 0.59311  0.8451 │
      └                         ┘

  """
  @spec random(index, index) :: matrex
  def random(rows, columns) when is_integer(rows) and is_integer(columns),
    do: %Matrex{data: NIFs.random(rows, columns)}

  @doc """
  Create square matrix of random floats.

  See `random/2` for details.

  ## Example

      iex> Matrex.random(3)
      #Matrex[3×3]
      ┌                         ┐
      │ 0.66438 0.31026 0.98602 │
      │ 0.82127 0.04701 0.13278 │
      │ 0.96935 0.70772 0.98738 │
      └                         ┘
  """
  @spec random(index) :: matrex
  def random(size) when is_integer(size), do: random(size, size)

  @doc """
  Resize matrix by scaling its dimenson with `scale`. NIF.

  ## Examples

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex(3)> Matrex.resize(m, 2)
      #Matrex[6×6]
      ┌                                                 ┐
      │     8.0     8.0     1.0     1.0     6.0     6.0 │
      │     8.0     8.0     1.0     1.0     6.0     6.0 │
      │     3.0     3.0     5.0     5.0     7.0     7.0 │
      │     3.0     3.0     5.0     5.0     7.0     7.0 │
      │     4.0     4.0     9.0     9.0     2.0     2.0 │
      │     4.0     4.0     9.0     9.0     2.0     2.0 │
      └                                                 ┘

      iex(4)> m = Matrex.magic(5)
      #Matrex[5×5]
      ┌                                         ┐
      │    16.0    23.0     5.0     7.0    14.0 │
      │    22.0     4.0     6.0    13.0    20.0 │
      │     3.0    10.0    12.0    19.0    21.0 │
      │     9.0    11.0    18.0    25.0     2.0 │
      │    15.0    17.0    24.0     1.0     8.0 │
      └                                         ┘
      iex(5)> Matrex.resize(m, 0.5)
      #Matrex[3×3]
      ┌                         ┐
      │    16.0    23.0     7.0 │
      │    22.0     4.0    13.0 │
      │     9.0    11.0    25.0 │
      └                         ┘
  """
  @spec resize(matrex, number, :nearest | :bilinear) :: matrex
  def resize(matrex, scale, method \\ :nearest)

  def resize(%Matrex{} = matrex, 1, _), do: matrex

  def resize(%Matrex{data: data}, scale, :nearest) when is_number(scale) and scale > 0,
    do: %Matrex{data: NIFs.resize(data, scale)}

  @doc """
  Reshapes list of values into a matrix of given size or changes the shape of existing matrix.

  Takes a list or anything, that implements `Enumerable.to_list/1`.

  Can take a list of matrices and concatenate into one big matrix.

  Raises `ArgumentError` if lsit size and given shape do not match.

  ## Example

      iex> [1, 2, 3, 4, 5, 6] |> Matrex.reshape(2, 3)
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      └                         ┘

      iex> Matrex.reshape([Matrex.zeros(2), Matrex.ones(2),
      ...> Matrex.fill(3, 2, 2.0), Matrex.fill(3, 2, 3.0)], 2, 2)
      #Matrex[5×4]
      ┌                                 ┐
      │     0.0     0.0     1.0     1.0 │
      │     0.0     0.0     1.0     1.0 │
      │     2.0     2.0     3.0     3.0 │
      │     2.0     2.0     3.0     3.0 │
      │     2.0     2.0     3.0     3.0 │
      └                                 ┘

      iex> Matrex.reshape(1..6, 2, 3)
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      └                         ┘

      iex> Matrex.new("1 2 3; 4 5 6") |> Matrex.reshape(3, 2)
      #Matrex[3×2]
      ┌                 ┐
      │     1.0     2.0 │
      │     3.0     4.0 │
      │     5.0     6.0 │
      └                 ┘

  """
  @spec reshape([element], index, index) :: matrex
  @spec reshape(Enumerable.t(), index, index) :: matrex
  def reshape([], _, _), do: raise(ArgumentError)

  def reshape([%Matrex{} | _] = list_of_ma, _rows, columns) do
    list_of_ma
    |> Enum.chunk(columns)
    |> new()
  end

  def reshape([_ | _] = list, rows, columns),
    do: %Matrex{
      data:
        do_reshape(
          <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32>>,
          list,
          rows,
          columns
        )
    }

  def reshape(
        %Matrex{
          data:
            <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32,
              _matrix::binary>>
        },
        new_rows,
        new_columns
      )
      when rows * columns != new_rows * new_columns,
      do:
        raise(
          ArgumentError,
          message:
            "Cannot reshape: #{rows}×#{columns} does not fit into #{new_rows}×#{new_columns}."
        )

  def reshape(
        %Matrex{data: <<_rows::binary-4, _columns::binary-4, matrix::binary>>},
        new_rows,
        new_columns
      ),
      do: %Matrex{
        data:
          <<new_rows::unsigned-integer-little-32, new_columns::unsigned-integer-little-32,
            matrix::binary>>
      }

  def reshape(input, rows, columns), do: input |> Enum.to_list() |> reshape(rows, columns)

  defp do_reshape(data, [], 1, 0), do: data

  defp do_reshape(_data, [], _, _),
    do: raise(ArgumentError, message: "Not enough elements for this shape")

  defp do_reshape(_data, [_ | _], 1, 0),
    do: raise(ArgumentError, message: "Too much elements for this shape")

  # Another row is ready, restart counters
  defp do_reshape(
         <<_rows::unsigned-integer-little-32, columns::unsigned-integer-little-32, _::binary>> =
           data,
         list,
         row,
         0
       ),
       do: do_reshape(data, list, row - 1, columns)

  defp do_reshape(
         <<_rows::unsigned-integer-little-32, _columns::unsigned-integer-little-32, _::binary>> =
           data,
         [elem | tail],
         row,
         column
       ) do
    do_reshape(<<data::binary, float_to_binary(elem)::binary-4>>, tail, row, column - 1)
  end

  @doc """
  Return matrix row as list by one-based index.

  ## Example

      iex> m = Matrex.magic(5)
      #Matrex[5×5]
      ┌                                         ┐
      │    16.0    23.0     5.0     7.0    14.0 │
      │    22.0     4.0     6.0    13.0    20.0 │
      │     3.0    10.0    12.0    19.0    21.0 │
      │     9.0    11.0    18.0    25.0     2.0 │
      │    15.0    17.0    24.0     1.0     8.0 │
      └                                         ┘
      iex> Matrex.row_to_list(m, 3)
      [3.0, 10.0, 12.0, 19.0, 21.0]
  """
  @spec row_to_list(matrex, index) :: [element]
  def row_to_list(%Matrex{data: matrix}, row) when is_integer(row) and row > 0,
    do: NIFs.row_to_list(matrix, row - 1)

  @doc """
  Get row of matrix as matrix (vector) in matrex form. One-based.

  You can use shorter `matrex[n]` syntax for the same result.

  ## Example

      iex> m = Matrex.magic(5)
      #Matrex[5×5]
      ┌                                         ┐
      │    16.0    23.0     5.0     7.0    14.0 │
      │    22.0     4.0     6.0    13.0    20.0 │
      │     3.0    10.0    12.0    19.0    21.0 │
      │     9.0    11.0    18.0    25.0     2.0 │
      │    15.0    17.0    24.0     1.0     8.0 │
      └                                         ┘
      iex> Matrex.row(m, 4)
      #Matrex[1×5]
      ┌                                         ┐
      │     9.0    11.0    18.0    25.0     2.0 │
      └                                         ┘
      iex> m[4]
      #Matrex[1×5]
      ┌                                         ┐
      │     9.0    11.0    18.0    25.0     2.0 │
      └                                         ┘
  """
  @spec row(matrex, index) :: matrex
  def row(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            data::binary
          >>
        },
        row
      )
      when is_integer(row) and row > 0 and row <= rows,
      do: %Matrex{
        data:
          <<1::unsigned-integer-little-32, columns::unsigned-integer-little-32,
            binary_part(data, (row - 1) * columns * @element_size, columns * @element_size)::binary>>
      }

  @doc """
  Saves matrex into file.

  Binary (.mtx) and CSV formats are supported currently.

  Format is defined by the extension of the filename.

  ## Example

      iex> Matrex.random(5) |> Matrex.save("r.mtx")
      :ok
  """
  @spec save(matrex, binary) :: :ok | :error
  def save(
        %Matrex{
          data: matrix
        },
        file_name
      )
      when is_binary(file_name) do
    cond do
      :filename.extension(file_name) == ".mtx" ->
        File.write!(file_name, matrix)

      :filename.extension(file_name) == ".csv" ->
        csv =
          matrix
          |> NIFs.to_list_of_lists()
          |> Enum.reduce("", fn row_list, acc ->
            acc <>
              Enum.reduce(row_list, "", fn elem, line ->
                line <> element_to_string(elem) <> ","
              end) <> "\n"
          end)

        File.write!(file_name, csv)

      true ->
        raise "Unknown file format: #{file_name}"
    end
  end

  @spec element_to_string(element) :: binary
  # Save zero values without fraction part to save space
  defp element_to_string(0.0), do: "0"
  defp element_to_string(val) when is_float(val), do: Float.to_string(val)
  defp element_to_string(NaN), do: "NaN"
  defp element_to_string(Inf), do: "Inf"
  defp element_to_string(NegInf), do: "-Inf"

  @doc """
  Transfer one-element matrix to a scalar value.

  Differently from `first/1` will not match and throw an error,
  if matrix contains more than one element.

  ## Example

      iex> Matrex.new([[1.234]]) |> Matrex.scalar()
      1.234

      iex> Matrex.new([[0]]) |> Matrex.divide(0) |> Matrex.scalar()
      NaN

      iex> Matrex.new([[1.234, 5.678]]) |> Matrex.scalar()
      ** (FunctionClauseError) no function clause matching in Matrex.scalar/1
  """
  @spec scalar(matrex) :: element
  def scalar(%Matrex{
        data: <<1::unsigned-integer-little-32, 1::unsigned-integer-little-32, elem::binary-4>>
      }),
      do: binary_to_float(elem)

  @doc """
  Set element of matrix at the specified position (one-based) to new value.

  ## Example

      iex> m = Matrex.ones(3)
      #Matrex[3×3]
      ┌                         ┐
      │     1.0     1.0     1.0 │
      │     1.0     1.0     1.0 │
      │     1.0     1.0     1.0 │
      └                         ┘
      iex> m = Matrex.set(m, 2, 2, 0)
      #Matrex[3×3]
      ┌                         ┐
      │     1.0     1.0     1.0 │
      │     1.0     0.0     1.0 │
      │     1.0     1.0     1.0 │
      └                         ┘
      iex> m = Matrex.set(m, 3, 2, NegInf)
      #Matrex[3×3]
      ┌                         ┐
      │     1.0     1.0     1.0 │
      │     1.0     0.0     1.0 │
      │     1.0     1.0     1.0 │
      └                         ┘
  """
  @spec set(matrex, index, index, element) :: matrex
  def set(
        %Matrex{
          data:
            <<
              rows::unsigned-integer-little-32,
              cols::unsigned-integer-little-32,
              _data::binary
            >> = matrix
        },
        row,
        column,
        value
      )
      when (is_number(value) or value in [NaN, Inf, NegInf]) and row > 0 and column > 0 and
             row <= rows and column <= cols,
      do: %Matrex{
        data: NIFs.set(matrix, row - 1, column - 1, float_to_binary(value))
      }

  @doc """
  Set column of a matrix to the values from the given 1-column matrix. NIF.

  ## Example

      iex> m = Matrex.reshape(1..6, 3, 2)

  """
  @spec set_column(matrex, index, matrex) :: matrex
  def set_column(
        %Matrex{
          data:
            <<rows::unsigned-integer-little-32, columns::unsigned-integer-little-32,
              _rest::binary>> = matrix
        },
        column,
        %Matrex{
          data:
            <<
              rows::unsigned-integer-little-32,
              1::unsigned-integer-little-32,
              _rest2::binary
            >> = column_matrix
        }
      )
      when column in 1..columns,
      do: %Matrex{data: NIFs.set_column(matrix, column - 1, column_matrix)}

  @doc """
  Return size of matrix as `{rows, cols}`

  ## Example

      iex> m = Matrex.random(2,3)
      #Matrex[2×3]
      ┌                         ┐
      │ 0.69745 0.23668 0.36376 │
      │ 0.63423 0.29651 0.22844 │
      └                         ┘
      iex> Matrex.size(m)
      {2, 3}
  """
  @spec size(matrex) :: {index, index}
  def size(%Matrex{
        data: <<
          rows::unsigned-integer-little-32,
          cols::unsigned-integer-little-32,
          _rest::binary
        >>
      }),
      do: {rows, cols}

  @doc """
  Produces element-wise squared matrix. NIF through `multiply/4`.


  ## Example

      iex> m = Matrex.new("1 2 3; 4 5 6")
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      └                         ┘
      iex> Matrex.square(m)
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     4.0     9.0 │
      │    16.0    25.0    36.0 │
      └                         ┘

  """
  @spec square(matrex) :: matrex
  def square(%Matrex{data: matrix}), do: %Matrex{data: Matrex.NIFs.multiply(matrix, matrix)}

  @doc """
  Returns submatrix for a given matrix. NIF.

  Rows and columns ranges are inclusive and one-based.

  ## Example

      iex> m = Matrex.new("1 2 3; 4 5 6; 7 8 9")
      #Matrex[3×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      │     7.0     8.0     9.0 │
      └                         ┘
      iex> Matrex.submatrix(m, 2..3, 2..3)
      #Matrex[2×2]
      ┌                ┐
      │    5.0     6.0 │
      │    8.0     9.0 │
      └                ┘
  """
  @spec submatrix(matrex, Range.t(), Range.t()) :: matrex
  def submatrix(
        %Matrex{
          data:
            <<
              rows::unsigned-integer-little-32,
              cols::unsigned-integer-little-32,
              _rest::binary
            >> = data
        },
        row_from..row_to,
        col_from..col_to
      )
      when row_from in 1..rows and row_to in row_from..rows and col_from in 1..cols and
             col_to in col_from..cols,
      do: %Matrex{data: NIFs.submatrix(data, row_from - 1, row_to - 1, col_from - 1, col_to - 1)}

  def submatrix(%Matrex{} = matrex, rows, cols),
    do:
      raise(
        RuntimeError,
        message:
          "Submatrix position out of range or malformed: position is (#{Kernel.inspect(rows)}, #{
            Kernel.inspect(cols)
          }), source size is (#{Kernel.inspect(1..matrex[:rows])}, #{
            Kernel.inspect(1..matrex[:columns])
          })"
      )

  @doc """
  Substracts two matrices or matrix from scalar element-wise. NIF.

  Raises `ErlangError` if matrices' sizes do not match.

  ## Examples

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]]) |>
      ...> Matrex.substract(Matrex.new([[5, 2, 1], [3, 4, 6]]))
      #Matrex[2×3]
      ┌                         ┐
      │    -4.0     0.0     2.0 │
      │     1.0     1.0     0.0 │
      └                         ┘

      iex> Matrex.substract(1, Matrex.new([[1, 2, 3], [4, 5, 6]]))
      #Matrex[2×3]
      ┌                         ┐
      │     0.0     -1.0   -2.0 │
      │    -3.0    -4.0    -5.0 │
      └                         ┘
  """
  @spec substract(matrex | number, matrex) :: matrex
  def substract(%Matrex{data: first}, %Matrex{data: second}),
    do: %Matrex{data: NIFs.substract(first, second)}

  def substract(scalar, %Matrex{data: matrix}) when is_number(scalar),
    do: %Matrex{data: NIFs.substract_from_scalar(scalar, matrix)}

  def substract(%Matrex{data: matrix}, scalar) when is_number(scalar),
    do: %Matrex{data: NIFs.add_scalar(matrix, -scalar)}

  @doc """
  Substracts the second matrix from the first. Inlined.

  Raises `ErlangError` if matrices' sizes do not match.

  ## Example

      iex> Matrex.new([[1, 2, 3], [4, 5, 6]]) |>
      ...> Matrex.substract_inverse(Matrex.new([[5, 2, 1], [3, 4, 6]]))
      #Matrex[2×3]
      ┌                         ┐
      │     4.0     0.0    -2.0 │
      │    -1.0    -1.0     0.0 │
      └                         ┘
  """
  @spec substract_inverse(matrex, matrex) :: matrex
  def substract_inverse(%Matrex{} = first, %Matrex{} = second), do: substract(second, first)

  @doc """
  Sums all elements. NIF.

  Can return special float values as atoms.

  ## Example

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> Matrex.sum(m)
      45.0

      iex> m = Matrex.new("1 Inf; 2 3")
      #Matrex[2×2]
      ┌                 ┐
      │     1.0     ∞   │
      │     2.0     3.0 │
      └                 ┘
      iex> sum(m)
      Inf
  """
  @spec sum(matrex) :: element
  def sum(%Matrex{data: matrix}), do: NIFs.sum(matrix)

  @doc """
  Converts to flat list. NIF.

  ## Example

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> Matrex.to_list(m)
      [8.0, 1.0, 6.0, 3.0, 5.0, 7.0, 4.0, 9.0, 2.0]
  """
  @spec to_list(matrex) :: list(element)
  def to_list(%Matrex{data: matrix}), do: NIFs.to_list(matrix)

  @doc """
  Converts to list of lists. NIF.

  ## Examples

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> Matrex.to_list_of_lists(m)
      [[8.0, 1.0, 6.0], [3.0, 5.0, 7.0], [4.0, 9.0, 2.0]]

      iex> r = Matrex.divide(Matrex.eye(3), Matrex.zeros(3))
      #Matrex[3×3]
      ┌                         ┐
      │     ∞      NaN     NaN  │
      │    NaN      ∞      NaN  │
      │    NaN     NaN      ∞   │
      └                         ┘
      iex> Matrex.to_list_of_lists(r)
      [[Inf, NaN, NaN], [NaN, Inf, NaN], [NaN, NaN, Inf]]

  """
  @spec to_list_of_lists(matrex) :: list(list(element))
  def to_list_of_lists(%Matrex{data: matrix}), do: NIFs.to_list_of_lists(matrix)

  @doc """
  Convert any matrix m×n to a row matrix 1×(m*n).

  ## Example

      iex> m = Matrex.magic(3)
      #Matrex[3×3]
      ┌                         ┐
      │     8.0     1.0     6.0 │
      │     3.0     5.0     7.0 │
      │     4.0     9.0     2.0 │
      └                         ┘
      iex> Matrex.to_row(m)
      #Matrex[1×9]
      ┌                                                                         ┐
      │     8.0     1.0     6.0     3.0     5.0     7.0     4.0     9.0     2.0 │
      └                                                                         ┘

  """
  @spec to_row(matrex) :: matrex
  def to_row(
        %Matrex{
          data: <<
            1::unsigned-integer-little-32,
            _rest::binary
          >>
        } = m
      ),
      do: m

  def to_row(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            _rest::binary
          >>
        } = m
      ),
      do: reshape(m, 1, rows * columns)

  @doc """
  Transposes a matrix. NIF.

  ## Example

      iex> m = Matrex.new([[1,2,3],[4,5,6]])
      #Matrex[2×3]
      ┌                         ┐
      │     1.0     2.0     3.0 │
      │     4.0     5.0     6.0 │
      └                         ┘
      iex> Matrex.transpose(m)
      #Matrex[3×2]
      ┌                 ┐
      │     1.0     4.0 │
      │     2.0     5.0 │
      │     3.0     6.0 │
      └                 ┘
  """
  @spec transpose(matrex) :: matrex
  # Vectors are transposed by simply reshaping
  def transpose(
        %Matrex{
          data: <<
            1::unsigned-integer-little-32,
            columns::unsigned-integer-little-32,
            _rest::binary
          >>
        } = m
      ),
      do: reshape(m, columns, 1)

  def transpose(
        %Matrex{
          data: <<
            rows::unsigned-integer-little-32,
            1::unsigned-integer-little-32,
            _rest::binary
          >>
        } = m
      ),
      do: reshape(m, 1, rows)

  def transpose(%Matrex{data: matrix}), do: %Matrex{data: NIFs.transpose(matrix)}

  @doc """
  Create matrix of zeros of the specified size. NIF, using `memset()`.

  Faster, than `fill(rows, cols, 0)`.

  ## Example

      iex> Matrex.zeros(4,3)
      #Matrex[4×3]
      ┌                         ┐
      │     0.0     0.0     0.0 │
      │     0.0     0.0     0.0 │
      │     0.0     0.0     0.0 │
      │     0.0     0.0     0.0 │
      └                         ┘
  """
  @spec zeros(index, index) :: matrex
  def zeros(rows, cols) when is_integer(rows) and is_integer(cols),
    do: %Matrex{data: NIFs.zeros(rows, cols)}

  @doc """
  Create square matrix of size `size` rows × `size` columns, filled with zeros. Inlined.

  ## Example

      iex> Matrex.zeros(3)
      #Matrex[3×3]
      ┌                         ┐
      │     0.0     0.0     0.0 │
      │     0.0     0.0     0.0 │
      │     0.0     0.0     0.0 │
      └                         ┘
  """
  @spec zeros(index | {index, index}) :: matrex
  def zeros({rows, cols}), do: zeros(rows, cols)
  def zeros(size), do: zeros(size, size)
end
