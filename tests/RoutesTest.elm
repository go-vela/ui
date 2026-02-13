{--
SPDX-License-Identifier: Apache-2.0
--}


module RoutesTest exposing (testApiSecretEndpointEncoding, testHref, testMatch, testPathFromString, testPathFromStringFullUrl, testPathFromStringNoScheme, testPathFromStringWithHash, testPathFromStringWithQuery, testPathFromStringWithQueryAndHash, testRepoPathDecoding, testRepoPathEncoding, testRouteToUrl, testSecretsPathDecoding, testSecretsPathEncoding)

import Api.Endpoint
import Expect
import Route.Path
import Test exposing (..)
import Url exposing (Url)
import Utils.Routes



-- Route.Path.toString


testHref : Test
testHref =
    test "returns the href of a route" <|
        \_ ->
            Route.Path.toString Route.Path.Account_Login
                |> Expect.equal "/account/login"



-- Route.Path.fromUrl


testMatch : Test
testMatch =
    describe "route gets matched as intended for given url"
        [ testUrl "/account/login" Route.Path.Account_Login
        , testUrl "/asdf" (Route.Path.Org_ { org = "asdf" })
        , testUrl "/my-org/builds" (Route.Path.Org__Builds { org = "my-org" })
        , testUrl "/" Route.Path.Home_
        ]


testUrl : String -> Route.Path.Path -> Test
testUrl p route =
    test ("Testing '" ++ p) <|
        \_ ->
            makeUrl p
                |> Route.Path.fromUrl
                |> Expect.equal route


makeUrl : String -> Url
makeUrl p =
    { protocol = Url.Http
    , host = "foo.com"
    , port_ = Nothing
    , path = p
    , query = Nothing
    , fragment = Nothing
    }



-- Route.Path.toString


testRouteToUrl : Test
testRouteToUrl =
    test "Login -> /account/login" <|
        \_ ->
            Route.Path.toString Route.Path.Account_Login
                |> Expect.equal "/account/login"



-- Utils.Routes.pathFromString


testPathFromString : Test
testPathFromString =
    test "/account/login -> { path }" <|
        \_ ->
            Utils.Routes.pathFromString "/account/login"
                |> Expect.equal { path = "/account/login", query = Nothing, hash = Nothing }


testPathFromStringFullUrl : Test
testPathFromStringFullUrl =
    test "http://example.com/account/login -> { path }" <|
        \_ ->
            Utils.Routes.pathFromString "http://example.com/account/login"
                |> Expect.equal { path = "/account/login", query = Nothing, hash = Nothing }


testPathFromStringNoScheme : Test
testPathFromStringNoScheme =
    test "example.com/account/login -> { path }" <|
        \_ ->
            Utils.Routes.pathFromString "example.com/account/login"
                |> Expect.equal { path = "/account/login", query = Nothing, hash = Nothing }


testPathFromStringWithQuery : Test
testPathFromStringWithQuery =
    test "/account/login?foo=bar -> { path }" <|
        \_ ->
            Utils.Routes.pathFromString "/account/login?foo=bar"
                |> Expect.equal { path = "/account/login", query = Just "foo=bar", hash = Nothing }


testPathFromStringWithHash : Test
testPathFromStringWithHash =
    test "/account/login#foo:bar:baz -> { path }" <|
        \_ ->
            Utils.Routes.pathFromString "/account/login#foo:bar:baz"
                |> Expect.equal { path = "/account/login", query = Nothing, hash = Just "foo:bar:baz" }


testPathFromStringWithQueryAndHash : Test
testPathFromStringWithQueryAndHash =
    test "/account/login?foo=bar#foo:bar:baz -> { path }" <|
        \_ ->
            Utils.Routes.pathFromString "/account/login?foo=bar#foo:bar:baz"
                |> Expect.equal { path = "/account/login", query = Just "foo=bar", hash = Just "foo:bar:baz" }



-- Route.Path.toString (encode)


testSecretsPathEncoding : Test
testSecretsPathEncoding =
    describe "secrets routes encode special characters" <|
        [ test "org secret name" <|
            \_ ->
                Route.Path.toString
                    (Route.Path.Dash_Secrets_Engine__Org_Org__Name_
                        { engine = "native"
                        , org = "octocat"
                        , name = "my secret/name"
                        }
                    )
                    |> Expect.equal "/-/secrets/native/org/octocat/my%20secret%2Fname"
        , test "shared secret team and name" <|
            \_ ->
                Route.Path.toString
                    (Route.Path.Dash_Secrets_Engine__Shared_Org__Team__Name_
                        { engine = "native"
                        , org = "octocat"
                        , team = "team/name"
                        , name = "sp@ce value"
                        }
                    )
                    |> Expect.equal "/-/secrets/native/shared/octocat/team%2Fname/sp%40ce%20value"
        , test "secret name with hash" <|
            \_ ->
                Route.Path.toString
                    (Route.Path.Dash_Secrets_Engine__Org_Org__Name_
                        { engine = "native"
                        , org = "octocat"
                        , name = "hash#value"
                        }
                    )
                    |> Expect.equal "/-/secrets/native/org/octocat/hash%23value"
        ]



-- Route.Path.fromString (decode)


testSecretsPathDecoding : Test
testSecretsPathDecoding =
    describe "secrets routes decode encoded characters" <|
        [ test "org secret name" <|
            \_ ->
                Route.Path.fromString "/-/secrets/native/org/octocat/my%20secret%2Fname"
                    |> Expect.equal
                        (Just
                            (Route.Path.Dash_Secrets_Engine__Org_Org__Name_
                                { engine = "native"
                                , org = "octocat"
                                , name = "my secret/name"
                                }
                            )
                        )
        , test "shared secret team and name" <|
            \_ ->
                Route.Path.fromString "/-/secrets/native/shared/octocat/team%2Fname/sp%40ce%20value"
                    |> Expect.equal
                        (Just
                            (Route.Path.Dash_Secrets_Engine__Shared_Org__Team__Name_
                                { engine = "native"
                                , org = "octocat"
                                , team = "team/name"
                                , name = "sp@ce value"
                                }
                            )
                        )
        , test "secret name with hash" <|
            \_ ->
                Route.Path.fromString "/-/secrets/native/org/octocat/hash%23value"
                    |> Expect.equal
                        (Just
                            (Route.Path.Dash_Secrets_Engine__Org_Org__Name_
                                { engine = "native"
                                , org = "octocat"
                                , name = "hash#value"
                                }
                            )
                        )
        ]



-- Route.Path.toString (encode)


testRepoPathEncoding : Test
testRepoPathEncoding =
    describe "repo routes encode special characters" <|
        [ test "hyphenated repo" <|
            \_ ->
                Route.Path.toString
                    (Route.Path.Org__Repo_
                        { org = "my-org"
                        , repo = "my-repo"
                        }
                    )
                    |> Expect.equal "/my-org/my-repo"
        , test "org builds" <|
            \_ ->
                Route.Path.toString
                    (Route.Path.Org__Builds
                        { org = "my-org" }
                    )
                    |> Expect.equal "/my-org/builds"

        -- this is not a possible scenario, but just showing
        -- that encoding of segments works
        , test "repo with hash" <|
            \_ ->
                Route.Path.toString
                    (Route.Path.Org__Repo_
                        { org = "octocat"
                        , repo = "hashtag#repo"
                        }
                    )
                    |> Expect.equal "/octocat/hashtag%23repo"
        ]



-- Route.Path.fromString (decode)


testRepoPathDecoding : Test
testRepoPathDecoding =
    describe "repo routes decode encoded characters" <|
        [ test "hyphenated repo" <|
            \_ ->
                Route.Path.fromString "/my-org/my-repo"
                    |> Expect.equal
                        (Just
                            (Route.Path.Org__Repo_
                                { org = "my-org"
                                , repo = "my-repo"
                                }
                            )
                        )

        -- this is not a possible scenario, but just showing
        -- that decoding of segments works
        , test "repo with hash" <|
            \_ ->
                Route.Path.fromString "/octocat/hashtag%23repo"
                    |> Expect.equal
                        (Just
                            (Route.Path.Org__Repo_
                                { org = "octocat"
                                , repo = "hashtag#repo"
                                }
                            )
                        )
        ]



-- Api.Endpoint.toUrl


testApiSecretEndpointEncoding : Test
testApiSecretEndpointEncoding =
    test "API secret endpoint encodes hash" <|
        \_ ->
            Api.Endpoint.toUrl "http://localhost:8080"
                (Api.Endpoint.Secret "native" "repo" "my-org" "my-repo" "secret#hash")
                |> Expect.equal "http://localhost:8080/api/v1/secrets/native/repo/my-org/my-repo/secret%23hash"
