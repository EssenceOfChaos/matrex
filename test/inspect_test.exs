defmodule InspectTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  test "#inspect displays a matrix visualization to stdout" do
    matrix = Matrex.new([[1, 2, 3], [4, 5, 6]])
    expected = "Rows: 2 Columns: 3\n1 2 3\n4 5 6\n"

    output =
      capture_io(fn ->
        assert Matrex.inspect(matrix) == matrix
      end)

    assert output == expected
  end

  test "#inspect/1 inspects matrix" do
    matrix = Matrex.eye(5)

    assert Matrex.Inspect.do_inspect(matrix) ==
             "\e[0m#Matrex[\e[33m5\e[0m×\e[33m5\e[0m]\n\e[0m┌                                         ┐\n│\e[33m     1.0\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m\e[0m │\n│\e[33m\e[38;5;102m     0.0\e[33m     1.0\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m\e[0m │\n│\e[33m\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m     1.0\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m\e[0m │\n│\e[33m\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m     1.0\e[38;5;102m     0.0\e[33m\e[0m │\n│\e[33m\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m\e[38;5;102m     0.0\e[33m     1.0 \e[0m│\n\e[0m└                                         ┘"
  end

  test "#inspect/1 inspects matrix with infinities and NaNs" do
    one = Matrex.new("1 0 -1; 1 2 3; 4 5 6")
    two = Matrex.new("0 0 0; 0 1 0; 1 0 1")
    result = Matrex.divide(one, two)

    assert Matrex.Inspect.do_inspect(result) ==
             "\e[0m#Matrex[\e[33m3\e[0m×\e[33m3\e[0m]\n\e[0m┌                         ┐\n│\e[33m\e[36m     ∞  \e[33m\e[31m    NaN \e[33m\e[36m    -∞  \e[33m\e[0m │\n│\e[33m\e[36m     ∞  \e[33m     2.0\e[36m     ∞  \e[33m\e[0m │\n│\e[33m     4.0\e[36m     ∞  \e[33m     6.0 \e[0m│\n\e[0m└                         ┘"
  end

  test "#inspect/1 inspects large matrix, skipping rows" do
    matrix = Matrex.magic(100)

    assert Matrex.Inspect.do_inspect(matrix) ==
             "\e[0m#Matrex[\e[33m100\e[0m×\e[33m100\e[0m]\n\e[0m┌                                                                                     ┐\n│\e[33m     1.0  9999.0  9998.0     4.0     5.0\e[0m  … \e[33m    96.0    97.0  9903.0  9902.0   100.0\e[0m │\n│\e[33m   9.9e3   102.0   103.0  9897.0  9896.0\e[0m  … \e[33m  9805.0  9804.0   198.0   199.0  9801.0\e[0m │\n│\e[33m   9.8e3   202.0   203.0  9797.0  9796.0\e[0m  … \e[33m  9705.0  9704.0   298.0   299.0  9701.0\e[0m │\n│\e[33m   301.0  9699.0  9698.0   304.0   305.0\e[0m  … \e[33m   396.0   397.0  9603.0  9602.0   400.0\e[0m │\n│\e[33m   401.0  9599.0  9598.0   404.0   405.0\e[0m  … \e[33m   496.0   497.0  9503.0  9502.0   500.0\e[0m │\n│\e[33m   9.5e3   502.0   503.0  9497.0  9496.0\e[0m  … \e[33m  9405.0  9404.0   598.0   599.0  9401.0\e[0m │\n│\e[33m   9.4e3   602.0   603.0  9397.0  9396.0\e[0m  … \e[33m  9305.0  9304.0   698.0   699.0  9301.0\e[0m │\n│\e[33m   701.0  9299.0  9298.0   704.0   705.0\e[0m  … \e[33m   796.0   797.0  9203.0  9202.0   800.0\e[0m │\n│\e[33m   801.0  9199.0  9198.0   804.0   805.0\e[0m  … \e[33m   896.0   897.0  9103.0  9102.0   900.0\e[0m │\n│\e[33m   9.1e3   902.0   903.0  9097.0  9096.0\e[0m  … \e[33m  9005.0  9004.0   998.0   999.0  9001.0\e[0m │\n│     ⋮       ⋮       ⋮       ⋮       ⋮    …      ⋮       ⋮       ⋮       ⋮       ⋮   │\n│\e[33m  9101.0   899.0   898.0  9104.0  9105.0\e[0m  … \e[33m  9196.0  9197.0   803.0   802.0   9.2e3\e[0m │\n│\e[33m  9201.0   799.0   798.0  9204.0  9205.0\e[0m  … \e[33m  9296.0  9297.0   703.0   702.0   9.3e3\e[0m │\n│\e[33m   700.0  9302.0  9303.0   697.0   696.0\e[0m  … \e[33m   605.0   604.0  9398.0  9399.0   601.0\e[0m │\n│\e[33m   600.0  9402.0  9403.0   597.0   596.0\e[0m  … \e[33m   505.0   504.0  9498.0  9499.0   501.0\e[0m │\n│\e[33m  9501.0   499.0   498.0  9504.0  9505.0\e[0m  … \e[33m  9596.0  9597.0   403.0   402.0   9.6e3\e[0m │\n│\e[33m  9601.0   399.0   398.0  9604.0  9605.0\e[0m  … \e[33m  9696.0  9697.0   303.0   302.0   9.7e3\e[0m │\n│\e[33m   300.0  9702.0  9703.0   297.0   296.0\e[0m  … \e[33m   205.0   204.0  9798.0  9799.0   201.0\e[0m │\n│\e[33m   200.0  9802.0  9803.0   197.0   196.0\e[0m  … \e[33m   105.0   104.0  9898.0  9899.0   101.0\e[0m │\n│\e[33m  9901.0    99.0    98.0  9904.0  9905.0\e[0m  … \e[33m  9996.0  9997.0     3.0     2.0   1.0e4 \e[0m│\n\e[0m└                                                                                     ┘"
  end

  test "#heatmap generates monochrome image of the matrix" do
    m = Matrex.magic(4)

    expected =
      "\e[0m#Matrex[\e[33m4\e[0m×\e[33m4\e[0m]\n\e[0m┌    ┐\n│\e[48;2;0;0;0;38;2;187;187;187m▄\e[48;2;238;238;238;38;2;85;85;85m▄\e[48;2;221;221;221;38;2;102;102;102m▄\e[48;2;51;51;51;38;2;136;136;136m▄\e[0m│\n│\e[48;2;119;119;119;38;2;204;204;204m▄\e[48;2;153;153;153;38;2;34;34;34m▄\e[48;2;170;170;170;38;2;17;17;17m▄\e[48;2;68;68;68;38;2;255;255;255m▄\e[0m│\n\e[0m└    ┘\n"

    output =
      capture_io(fn ->
        assert Matrex.heatmap(m, :mono24bit) == m
      end)

    assert output == expected
  end

  test "#heatmap prints last row of matrices with odd rows number" do
    m = Matrex.magic(3)

    expected =
      "\e[0m#Matrex[\e[33m3\e[0m×\e[33m3\e[0m]\n\e[0m┌   ┐\n│\e[48;2;223;223;223;38;2;63;63;63m▄\e[48;2;0;0;0;38;2;127;127;127m▄\e[48;2;159;159;159;38;2;191;191;191m▄\e[0m│\n│\e[7m\e[38;2;95;95;95m▄\e[38;2;255;255;255m▄\e[38;2;31;31;31m▄\e[0m│\n\e[0m└   ┘\n"

    output =
      capture_io(fn ->
        assert Matrex.heatmap(m, :mono24bit) == m
      end)

    assert output == expected
  end

  test "#heatmap unites cells of the same color" do
    m = Matrex.zeros(3)

    expected =
      "\e[0m#Matrex[\e[33m3\e[0m×\e[33m3\e[0m]\n\e[0m┌   ┐\n│\e[48;2;0;0;0;38;2;0;0;0m▄▄▄\e[0m│\n│\e[7m\e[38;2;0;0;0m▄▄▄\e[0m│\n\e[0m└   ┘\n"

    output =
      capture_io(fn ->
        assert Matrex.heatmap(m, :mono24bit) == m
      end)

    assert output == expected
  end

  test "#heatmap(:mono256) uses 256 color palette" do
    m = Matrex.reshape(1..64, 8, 8)

    expected =
      "\e[0m#Matrex[\e[33m8\e[0m×\e[33m8\e[0m]\n\e[0m┌        ┐\n│\e[48;5;232;38;5;234m▄\e[38;5;235m▄▄\e[48;5;233;38;5;236m▄▄▄\e[48;5;234;38;5;237m▄▄\e[0m│\n│\e[48;5;237;38;5;240m▄\e[48;5;238;38;5;241m▄▄▄\e[48;5;239;38;5;242m▄▄\e[48;5;240m▄\e[38;5;243m▄\e[0m│\n│\e[48;5;243;38;5;246m▄\e[48;5;244m▄\e[38;5;247m▄▄\e[48;5;245;38;5;248m▄▄▄\e[48;5;246;38;5;249m▄\e[0m│\n│\e[48;5;249;38;5;252m▄▄\e[48;5;250;38;5;253m▄▄▄\e[48;5;251;38;5;254m▄▄\e[48;5;252;38;5;255m▄\e[0m│\n\e[0m└        ┘\n"

    output =
      capture_io(fn ->
        assert Matrex.heatmap(m, :mono256) == m
      end)

    assert output == expected
  end

  test "#heatmap(:color256) uses 256 color palette" do
    m = Matrex.reshape(1..64, 8, 8)

    expected =
      "\e[0m#Matrex[\e[33m8\e[0m×\e[33m8\e[0m]\n\e[0m┌        ┐\n│\e[48;5;17;38;5;19m▄▄\e[48;5;18;38;5;20m▄▄▄▄\e[48;5;19m▄▄\e[0m│\n│\e[48;5;20;38;5;37m▄\e[48;5;26m▄▄▄\e[48;5;32;38;5;36m▄▄\e[48;5;31;38;5;42m▄\e[38;5;41m▄\e[0m│\n│\e[48;5;41;38;5;46m▄\e[38;5;82m▄▄\e[48;5;40;38;5;118m▄▄▄\e[48;5;46;38;5;154m▄▄\e[0m│\n│\e[48;5;190;38;5;208m▄▄\e[38;5;202m▄\e[48;5;220m▄▄\e[48;5;214;38;5;196m▄▄▄\e[0m│\n\e[0m└        ┘\n"

    output =
      capture_io(fn ->
        assert Matrex.heatmap(m, :color256) == m
      end)

    assert output == expected
  end

  test "#heatmap(:color8) uses 8 color palette" do
    m = Matrex.reshape(1..16, 4, 4)

    expected =
      "\e[0m#Matrex[\e[33m4\e[0m×\e[33m4\e[0m]\n\e[0m┌    ┐\n│\e[40;34m▄\e[44m▄\e[36m▄\e[32m▄\e[0m│\n│\e[42;33m▄▄\e[31m▄\e[43m▄\e[0m│\n\e[0m└    ┘\n"

    output =
      capture_io(fn ->
        assert Matrex.heatmap(m, :color8) == m
      end)

    assert output == expected
  end

  test "#heatmap(:mono8) uses b&w color palette" do
    m = Matrex.reshape(1..15, 5, 3)

    expected =
      "\e[0m#Matrex[\e[33m5\e[0m×\e[33m3\e[0m]\n\e[0m┌   ┐\n│\e[40;30m▄▄▄\e[0m│\n│\e[40;37m▄\e[47m▄▄\e[0m│\n│\e[7m\e[37m▄▄▄\e[0m│\n\e[0m└   ┘\n"

    output =
      capture_io(fn ->
        assert Matrex.heatmap(m, :mono8) == m
      end)

    assert output == expected
  end
end
