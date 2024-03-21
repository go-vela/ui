{--
SPDX-License-Identifier: Apache-2.0
--}

module RoutesTest exposing (testHref, testMatch, testRouteToUrl)

import Expect
import Route.Path
import Test exposing (..)
import Url exposing (Url)




-- href


testHref : Test
testHref =
    test "returns the href of a route" <|
        \_ ->
            Route.Path.toString Route.Path.AccountLogin
                |> Expect.equal "/account/login"



-- match


testMatch : Test
testMatch =
    describe "route gets matched as intended for given url"
        [ testUrl "/account/login" Route.Path.AccountLogin
        , testUrl "/asdf" (Route.Path.Org_ { org = "asdf" })
        , testUrl "/" Route.Path.Home
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



-- routeToUrl


testRouteToUrl : Test
testRouteToUrl =
    test "Login -> /account/login" <|
        \_ ->
            Route.Path.toString Route.Path.AccountLogin
                |> Expect.equal "/account/login"