{--
SPDX-License-Identifier: Apache-2.0
--}


module ArtifactsTest exposing (suite)

import Expect
import Pages.Org_.Repo_.Build_.Artifacts as Artifacts
import Test exposing (..)


suite : Test
suite =
    describe "Artifacts"
        [ describe "objectKeyToFileName"
            [ test "returns the final path segment" <|
                \_ ->
                    Artifacts.objectKeyToFileName "github/octocat/1/test-results.xml"
                        |> Expect.equal "test-results.xml"
            , test "returns the key when no separators exist" <|
                \_ ->
                    Artifacts.objectKeyToFileName "coverage.html"
                        |> Expect.equal "coverage.html"
            , test "handles deeper paths" <|
                \_ ->
                    Artifacts.objectKeyToFileName "org/repo/build/artifacts/logs/output.txt"
                        |> Expect.equal "output.txt"
            ]
        ]
