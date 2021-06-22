{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.View exposing (addDeployment, addForm)

import Errors exposing (viewResourceError)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , div
        , h2
        , span
        , td
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , scope
        )
import Html.Events exposing (onClick)
import Pages.Deployments.Form exposing (viewAddedParameters, viewHelp, viewNameInput, viewParameterInput, viewSubmitButtons, viewValueInput)
import Pages.Deployments.Model
    exposing
        ( Model
        , Msg(..)
        , PartialModel
        )
import RemoteData exposing (RemoteData(..))
import Routes
import Svg.Attributes
import Table
import Url exposing (percentEncode)
import Util exposing (largeLoader)
import Vela
    exposing
        ( Deployment
        )


-- ADD SECRET
{-| addDeployment : takes partial model and renders the Add Deployment form
-}
addDeployment : PartialModel a msg -> Html Msg
addDeployment model =
    div [ class "manage-secret", Util.testAttribute "manage-secret" ]
        [ div []
            [ addForm model.deploymentModel
            ]
        ]

{-| addForm : renders secret update form for adding a new secret
-}
addForm : Model msg -> Html Msg
addForm deploymentModel =
    let
        deployment =
            deploymentModel.form
    in
    div [ class "secret-form" ]
        [ viewNameInput deployment.description False
        , viewValueInput deployment.ref "Secret Value"
        , viewParameterInput deployment deployment.parameterInput
        , viewSubmitButtons deploymentModel
        , viewHelp
        , div [ class "form-action" ]
            [ button [ class "button", class "-outline", onClick <| Pages.Deployments.Model.AddDeployment deploymentModel.engine ] [ text "Add" ]
            ]
        ]
