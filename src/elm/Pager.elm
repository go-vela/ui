{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pager exposing (defaultLabels, view)

import Api.Pagination as Pagination
import FeatherIcons
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (attribute, class, disabled)
import Html.Events exposing (onClick)
import LinkHeader exposing (WebLink)
import Util


type alias Labels =
    { previousLabel : String
    , nextLabel : String
    }


defaultLabels : Labels
defaultLabels =
    { previousLabel = "newer"
    , nextLabel = "older"
    }


{-| view : renders pager controls
-}
view : List WebLink -> Labels -> (Pagination.Page -> msg) -> Html msg
view links labels toMsg =
    let
        linkRels : List LinkHeader.LinkRel
        linkRels =
            List.map .rel links

        -- note: list is empty if there's only one page
        isFirst : Bool
        isFirst =
            List.member (LinkHeader.RelNext 2) linkRels

        maybePrevPage : Maybe LinkHeader.LinkRel
        maybePrevPage =
            linkRels
                |> List.filter
                    (\link ->
                        case link of
                            LinkHeader.RelPrev _ ->
                                True

                            _ ->
                                False
                    )
                |> List.head

        maybeNextPage : Maybe LinkHeader.LinkRel
        maybeNextPage =
            linkRels
                |> List.filter
                    (\link ->
                        case link of
                            LinkHeader.RelNext _ ->
                                True

                            _ ->
                                False
                    )
                |> List.head

        isLast : Bool
        isLast =
            case ( maybePrevPage, maybeNextPage ) of
                ( Just (LinkHeader.RelPrev _), Nothing ) ->
                    True

                _ ->
                    False

        nextPage : Int
        nextPage =
            case maybeNextPage of
                Just (LinkHeader.RelNext num) ->
                    num

                _ ->
                    1

        prevPage : Int
        prevPage =
            case maybePrevPage of
                Just (LinkHeader.RelPrev num) ->
                    num

                _ ->
                    1
    in
    -- only render if we have pagination
    if List.length links > 0 then
        div [ class "pager-actions" ]
            [ button [ disabled isFirst, Util.testAttribute "pager-previous", class "inverted", onClick (toMsg prevPage) ]
                [ FeatherIcons.chevronLeft
                    |> FeatherIcons.withSize 14
                    |> FeatherIcons.toHtml [ attribute "aria-hidden" "true" ]
                , text labels.previousLabel
                ]
            , button [ disabled isLast, Util.testAttribute "pager-next", class "inverted", onClick (toMsg nextPage) ]
                [ text labels.nextLabel
                , FeatherIcons.chevronRight
                    |> FeatherIcons.withSize 14
                    |> FeatherIcons.toHtml [ attribute "aria-hidden" "true" ]
                ]
            ]

    else
        text ""
