defmodule Vbt.URITest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  doctest Vbt.URI

  describe "to_string/1" do
    property "preserves scheme, userinfo, host, port, and authority" do
      check all uri <- uri() do
        vbt_uri = uri |> Vbt.URI.to_string() |> URI.parse()

        assert vbt_uri.scheme == uri.scheme
        assert vbt_uri.userinfo == uri.userinfo
        assert vbt_uri.host == uri.host
        assert vbt_uri.port == uri.port
        assert vbt_uri.authority == uri.authority
      end
    end

    property "sets path to /" do
      check all uri <- uri() do
        vbt_uri = uri |> Vbt.URI.to_string() |> URI.parse()
        assert vbt_uri.path == "/"
      end
    end

    property "encodes path, query, and fragment into fragment which starts with !" do
      check all uri <- uri() do
        assert "!" <> encoded_fragment = (uri |> Vbt.URI.to_string() |> URI.parse()).fragment

        expected_fragment =
          URI.to_string(%URI{uri | scheme: nil, host: nil, port: nil, authority: nil})

        if uri.path == nil,
          do: assert(encoded_fragment == expected_fragment),
          else: assert("/#{encoded_fragment}" == expected_fragment)
      end
    end

    test "raises if path doesn't start with /" do
      uri = %URI{Enum.at(uri(), 1) | path: "invalid_path"}
      expected_message = "the input path must start with /"
      assert_raise ArgumentError, expected_message, fn -> Vbt.URI.to_string(uri) end
    end
  end

  describe "parse/1" do
    property "returns the original input passed to to_string/1" do
      check all uri <- uri() do
        assert uri |> Vbt.URI.to_string() |> Vbt.URI.parse() == uri
      end
    end

    test "raises if path is not empty" do
      assert_raise ArgumentError, fn -> Vbt.URI.parse("http://some_server/foo/bar#!a=1") end
    end

    test "raises if query is not empty" do
      assert_raise ArgumentError, fn -> Vbt.URI.parse("http://some_server/?foo=1#!a=1") end
    end

    test "raises if fragment doesn't start with !" do
      assert_raise ArgumentError, fn -> Vbt.URI.parse("http://some_server/#a=1") end
    end
  end

  defp uri do
    gen all scheme <- constant_of(~w/http https/),
            uri <-
              fixed_map(%{
                scheme: constant(scheme),
                userinfo: one_of([constant(nil), userinfo()]),
                host: host(),
                port: one_of([default_port(scheme), non_default_port(scheme)]),
                path: one_of([constant(nil), map(multipart_string("/"), &"/#{&1}")]),
                query: one_of([constant(nil), query()]),
                fragment: one_of([constant(nil), alphanumeric_string()])
              }),
            do: set_authority(struct!(URI, uri))
  end

  defp userinfo, do: map(nonempty(list_of(alphanumeric_string())), &Enum.join(&1, ":"))

  defp default_port("http"), do: constant(80)
  defp default_port("https"), do: constant(443)

  defp non_default_port(scheme), do: filter(integer(1..65_535), &(&1 != default_port(scheme)))

  defp set_authority(%URI{userinfo: nil} = uri),
    do: %URI{uri | authority: normalized_host_address(uri)}

  defp set_authority(uri),
    do: %URI{uri | authority: "#{uri.userinfo}@#{normalized_host_address(uri)}"}

  defp normalized_host_address(%URI{scheme: "http", port: 80} = uri), do: uri.host
  defp normalized_host_address(%URI{scheme: "https", port: 443} = uri), do: uri.host
  defp normalized_host_address(uri), do: "#{uri.host}:#{uri.port}"

  defp host, do: one_of([constant("localhost"), multipart_string("."), ip_address()])

  defp query do
    gen all params <- map_of(alphanumeric_string(), alphanumeric_string()),
            do: URI.encode_query(params)
  end

  defp ip_address do
    integer(0..999)
    |> List.duplicate(4)
    |> fixed_list()
    |> map(&Enum.join(&1, "."))
  end

  defp multipart_string(separator) do
    alphanumeric_string()
    |> list_of()
    |> nonempty()
    |> map(&Enum.join(&1, separator))
  end

  defp alphanumeric_string, do: string(:alphanumeric, min_length: 1)

  defp constant_of(elements), do: one_of(Enum.map(elements, &constant/1))
end
