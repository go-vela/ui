module RoutesTest exposing (testHref, testMatch, testRouteToUrl)

import Expect
import Routes exposing (Route(..), routeToUrl)
import Test exposing (..)
import Url exposing (Url)



-- href


testHref : Test
testHref =
    test "returns the href of a route" <|
        \_ ->
            routeToUrl Routes.Login
                |> Expect.equal "/account/login"



-- match


testMatch : Test
testMatch =
    describe "route gets matched as intended for given url"
        [ testUrl "/account/login" Login
        , testUrl "/asdf" (OrgRepositories "asdf" Nothing Nothing)
        , testUrl "/" Overview
        ]


testUrl : String -> Route -> Test
testUrl p route =
    test ("Testing '" ++ p) <|
        \_ ->
            makeUrl p
                |> Routes.match
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
            Routes.routeToUrl Login
                |> Expect.equal "/account/login"
