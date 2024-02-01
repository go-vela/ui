{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Secrets.Engine_.Shared.Org_.Team_.Add exposing (Model, Msg, page, view)

import Auth
import Components.Form
import Components.SecretForm
import Effect exposing (Effect)
import Html exposing (div, h2, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import String.Extra
import Url
import Utils.Helpers as Util
import Vela exposing (defaultSecretPayload)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { engine : String, org : String, team : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { engine : String, org : String, team : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.team, Nothing )
            , ( "Secrets", Just <| Route.Path.SecretsEngine_SharedOrg_Team_ { engine = route.params.engine, org = route.params.org, team = route.params.team } )
            , ( "Add", Nothing )
            ]
        , repo = Nothing
        }



-- INIT


type alias Model =
    { team : String
    , name : String
    , value : String
    , events : List String
    , images : List String
    , image : String
    , allowCommand : Bool
    }


init : Shared.Model -> Route { engine : String, org : String, team : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { team =
            if route.params.team == "*" then
                ""

            else
                Maybe.withDefault route.params.team <| Url.percentDecode route.params.team
      , name = ""
      , value = ""
      , events = [ "push" ]
      , images = []
      , image = ""
      , allowCommand = True
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = -- SECRETS
      AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | TeamOnInput String
    | NameOnInput String
    | ValueOnInput String
    | ImageOnInput String
    | EventOnCheck String Bool
    | AddImage String
    | RemoveImage String
    | AllowCommandsOnClick String
    | SubmitForm


update : Shared.Model -> Route { engine : String, org : String, team : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- SECRETS
        AddSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = secret.name ++ " added to shared secrets."
                        , addToastIfUnique = True
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        TeamOnInput val ->
            ( { model | team = val }
            , Effect.none
            )

        NameOnInput val ->
            ( { model | name = val }
            , Effect.none
            )

        ValueOnInput val ->
            ( { model | value = val }
            , Effect.none
            )

        ImageOnInput val ->
            ( { model | image = val }
            , Effect.none
            )

        EventOnCheck event val ->
            let
                updatedEvents =
                    if val then
                        model.events
                            |> List.append [ event ]
                            |> List.Extra.unique

                    else
                        model.events
                            |> List.filter ((/=) event)
            in
            ( { model | events = updatedEvents }
            , Effect.none
            )

        AddImage image ->
            ( { model
                | images =
                    model.images
                        |> List.append [ image ]
                        |> List.Extra.unique
                , image = ""
              }
            , Effect.none
            )

        RemoveImage image ->
            ( { model
                | images =
                    model.images
                        |> List.filter ((/=) image)
              }
            , Effect.none
            )

        AllowCommandsOnClick val ->
            ( model
                |> (\m -> { m | allowCommand = Util.yesNoToBool val })
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    { defaultSecretPayload
                        | type_ = Just Vela.SharedSecret
                        , org = Just route.params.org
                        , repo = Nothing
                        , team = Just model.team
                        , name = Util.stringToMaybe model.name
                        , value = Util.stringToMaybe model.value
                        , events = Just model.events
                        , images = Just model.images
                        , allowCommand = Just model.allowCommand
                    }

                body =
                    Http.jsonBody <| Vela.encodeSecretPayload payload
            in
            ( model
            , Effect.addSharedSecret
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = AddSecretResponse
                , engine = route.params.engine
                , org = route.params.org
                , team = model.team
                , body = body
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { engine : String, org : String, team : String } -> Model -> View Msg
view shared route model =
    { title = "Add Secret"
    , body =
        [ div [ class "manage-secret", Util.testAttribute "manage-secret" ]
            [ div []
                [ h2 [] [ text <| String.Extra.toTitleCase "add shared secret" ]
                , div [ class "secret-form" ]
                    [ Components.Form.viewInput
                        { title = Just "Team"
                        , subtitle = Nothing
                        , id_ = "team"
                        , val = model.team
                        , placeholder_ = "GitHub Team"
                        , classList_ = [ ( "secret-team", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = TeamOnInput
                        , disabled_ = False
                        }
                    , Components.Form.viewInput
                        { title = Just "Name"
                        , subtitle = Nothing
                        , id_ = "name"
                        , val = model.name
                        , placeholder_ = "Secret Name"
                        , classList_ = [ ( "secret-name", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = NameOnInput
                        , disabled_ = False
                        }
                    , Components.Form.viewTextarea
                        { title = Just "Value"
                        , subtitle = Nothing
                        , id_ = "value"
                        , val = model.value
                        , placeholder_ = "secret-value"
                        , classList_ = [ ( "secret-value", True ) ]
                        , rows_ = Just 2
                        , wrap_ = Just "soft"
                        , msg = ValueOnInput
                        , disabled_ = False
                        }
                    , Components.SecretForm.viewEventsSelect shared
                        { msg = EventOnCheck
                        , events = model.events
                        , disabled_ = False
                        }
                    , Components.SecretForm.viewImagesInput
                        { onInput_ = ImageOnInput
                        , addImage = AddImage
                        , removeImage = RemoveImage
                        , images = model.images
                        , imageValue = model.image
                        , disabled_ = False
                        }
                    , Components.SecretForm.viewAllowCommandsInput
                        { msg = AllowCommandsOnClick
                        , value = model.allowCommand
                        , disabled_ = False
                        }
                    , Components.SecretForm.viewHelp shared.velaDocsURL
                    , Components.Form.viewButton
                        { msg = SubmitForm
                        , text_ = "Submit"
                        , classList_ = []
                        , disabled_ = False
                        }
                    ]
                ]
            ]
        ]
    }