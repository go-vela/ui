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


{-| User : A type representing a user.
-}
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
            Auth.Action.replaceRoute
                { path = Route.Path.Account_Login
                , query =
                    Dict.fromList
                        [ ( "from", Route.toString route ) ]
                , hash = Nothing
                }


{-| Renders whenever `Auth.Action.showLoadingPage` is returned from `onPageLoad`.
-}
viewLoadingPage : Shared.Model -> Route () -> View Never
viewLoadingPage shared route =
    View.fromString "Loading..."
