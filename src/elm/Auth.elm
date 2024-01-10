module Auth exposing (User, onPageLoad, viewLoadingPage)

import Auth.Action
import Dict
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


type alias User =
    { token : String
    }


{-| Called before an auth-only page is loaded.
-}
onPageLoad : Shared.Model -> Route () -> Auth.Action.Action User
onPageLoad shared route =
    -- todo: (?) check if the token is valid OR we are in the middle of getting redirected from the auth server
    case shared.token of
        Just token ->
            Auth.Action.loadPageWithUser
                { token = token
                }

        Nothing ->
            let
                authRedirect =
                    Maybe.withDefault "" <| Dict.get "auth_redirect" route.query

                redirectPage =
                    if authRedirect == "true" then
                        route.path

                    else
                        Route.Path.Login_
            in
            Auth.Action.pushRoute
                { -- path = Route.Path.Login_
                  path = redirectPage
                , query =
                    Dict.fromList
                        [ ( "from", route.url.path )
                        ]
                , hash = Nothing
                }


{-| Renders whenever `Auth.Action.showLoadingPage` is returned from `onPageLoad`.
-}
viewLoadingPage : Shared.Model -> Route () -> View Never
viewLoadingPage shared route =
    View.fromString "Loading..."
