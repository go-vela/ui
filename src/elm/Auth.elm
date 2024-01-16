{--
SPDX-License-Identifier: Apache-2.0
--}


module Auth exposing (User, onPageLoad, viewLoadingPage)

import Auth.Action
import Auth.Session exposing (Session(..))
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
    case shared.session of
        Authenticated { token } ->
            Auth.Action.loadPageWithUser
                { token = token
                }

        Unauthenticated ->
            Auth.Action.pushRoute
                { path = Route.Path.Login_
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
