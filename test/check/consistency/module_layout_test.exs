defmodule VbtCredo.Check.Consistency.ModuleLayoutTest do
  use Credo.TestHelper

  @described_check VbtCredo.Check.Consistency.ModuleLayout

  test "no errors are reported on a successful layout" do
    """
    defmodule Test do
      @moduledoc "some doc"

      @behaviour GenServer
      @behaviour Supervisor
    end
    """
    |> to_source_file
    |> refute_issues(@described_check)
  end

  test "moduledoc must appear before behaviour" do
    [issue] =
      """
      defmodule Test do
        @behaviour GenServer
        @moduledoc "some doc"
      end
      """
      |> to_source_file
      |> assert_issue(@described_check)

    assert issue.message == "Invalid placement of moduledoc."
  end
end