module Pages.Home_ exposing (Model, Msg, page, view)

import Effect exposing (Effect)
import Html exposing (Html)
import Html.Events
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Shared.Msg
import Vela exposing (CurrentUser)
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- INIT


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}
    , Effect.none
    )



-- UPDATE
-- put ToggleFavorite here? but i want that in the Shared.msg


type Msg
    = NoOp
    | SomeHomeMsg
    | SomeSharedMsg


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        SomeHomeMsg ->
            ( model
            , Effect.none
            )

        SomeSharedMsg ->
            ( model
            , Effect.someSharedMsg
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes current user, user input and action params and renders home page with favorited repos
-}
view : Model -> View Msg
view model =
    -- fill this with the actual code
    { title = "Pages.Home_New_"
    , body =
        [ Html.div []
            [ Html.text "This is the new Home page."
            , Html.div [] [ Html.button [ Html.Events.onClick SomeHomeMsg ] [ Html.text "trigger Page.Msg.Home.SubMsg" ] ]
            , Html.div [] [ Html.button [ Html.Events.onClick SomeSharedMsg ] [ Html.text "trigger Shared.Msg.SubMsg" ] ]
            ]
        ]
    }
