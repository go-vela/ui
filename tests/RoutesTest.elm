{--
SPDX-License-Identifier: Apache-2.0
--}


module RoutesTest exposing (testHref, testMatch, testPathFromString, testPathFromStringFullUrl, testPathFromStringNoLeadingSlash, testPathFromStringNoScheme, testPathFromStringWithHash, testPathFromStringWithQuery, testPathFromStringWithQueryAndHash, testRouteToUrl)

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
