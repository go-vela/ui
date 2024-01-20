{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.PageTemplate exposing (Model, Msg, page, view)

import Auth
import Effect exposing (Effect)
import Html
    exposing
        ( text
        )
import Layouts
import Page exposing (Page)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Shared
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update
        , subscriptions = subscriptions
        , view = view shared
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default
        { navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    {}


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = "Pages.PageTemplate"
    , body =
        [ Html.ul []
            [ Html.li [] [ text "this is a template page\n" ]
            , Html.li [] [ text "add page specific data to the Model like API resources\n" ]
            , Html.li [] [ text "apply any Layouts to the page in toLayout\n" ]
            , Html.li [] [ text "add html to the view to trigger page messages\n" ]
            , Html.li [] [ text "re-use components first, but add new components when necessary\n" ]
            , Html.li [] [ text "add page messages and pass them as components args\n" ]
            , Html.li [] [ text "use page messages to dispatch shared Effects and handle API calls\n" ]
            , Html.li [] [ text "use page messages and shared Effects to dispatch API calls\n" ]
            , Html.li [] [ text "add page specific subscriptions like page refresh and favicon updates\n" ]
            , Html.li [] [ text "try to implement things in the page!\n" ]
            , Html.li [] [ text "avoid using Shared.Model whenever possible!\n" ]
            ]
        ]
    }
