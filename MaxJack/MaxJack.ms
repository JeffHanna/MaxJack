/*
	MaxJack.ms
	Version: 1.01
	Created On: 12/13/2004
	Created By: Jeff Hanna
	Modified On: 12/31/2017
	Modified By: Jeff Hanna
	Tested with 3ds Max 2010 and 3ds Max 2018

	Copyright 2005 Jeff Hanna. All Rights Reserved.
	http://www.jeff-hanna.com

	Play a rousing game of blackjack inside of Max.

	v1.01 -	Updated directory paths to use newer Max versions UAC safe paths ($userscripts instead of $scripts, etc...)
	v1.00 -	Release version

	v0.94 -	Fixed Ace scoring (again). Added themed messageBoxes and queryBoxes. Changed order of images in the
					cardsDiamonds.jpg file.
					Split and Double Down are only allowed if the player's cash is greater than or equal to the current wager.
					If the dealer is dealt 2 aces on the initial deal then soft aces are allowed for the dealer.
	v0.93 -	Reworked player UI.
	v0.92 -	Fixed card/chip removal and soft Ace scoring.
	v0.91 -	Moved the loading of the table to later in the startup sequence. Moved some material initializing code out of loops as
					it didn't need to be run multiple times.
					Insurance payout works correctly now.
	v0.90 -	Fixed payout display to not double the value. Icons and macroscript created.
	v0.80 - 	Code functional and complete except for the timing issues. No macroscript yet.
	v0.12 -	Wrote a function with code to properly align and scale screen text. I haven't replaced the messageBox() calls yet,
					as using the screen text seems to exascerbate the timer() synchronization issues.
	v0.11 -	Changed all code using filterString() to address arrays within the dealer & player structures. No more string compares!
	v0.10 -	The proper number of chips for a winning hand are drawn.
	v0.09 -	Spit hands are check for blackjack as they are dealt.
	v0.08 -	Cards now animate across the table.
	v0.07 -	Cards are now displayed graphically in the viewport. The game holds the current scene and reconfigures
					the workspace accordingly upon startup. The held scene is retrieved upon exit.
	v0.06 -	Displays an "*" next to the current hand so the player can easily see which split hand they are playing.
					The bet/play UI now has a status label to show which hand is being played.
	v0.05 -	All basic blackjack rules are implemented and working. Display is only console based


	TODO:
	* Fix timer synchronization issues. The following items can't be fixed until that is taken care of
		* FIX THE FACT THAT THE LAST CARD (PLAYER AND DEALER) ISN'T BEING DRAWN/ANIMATED)!!! (when using screen text)
		* Animate chip removal (to player or to house)
		* Animate played cards to discard pile
		* Animate burn card after deal to discard pile
		* Animate red "shuffle" card from deck to discard pile
*/
(
	--*********************************************************************************************
	--LOCAL VARIABLES
	--*********************************************************************************************
	-- Standard set of 52 cards
	local CardDeckArray =	#(
													"2s", "3s", "4s", "5s", "6s", "7s", "8s", "9s", "10s", "Js", "Qs", "Ks", "As", \
													"2c", "3c", "4c", "5c", "6c", "7c", "8c", "9c", "10c", "Jc", "Qc", "Kc", "Ac", \
													"2h", "3h", "4h", "5h", "6h", "7h", "8h", "9h", "10h", "Jh", "Qh", "Kh", "Ah", \
													"2d", "3d", "4d", "5d", "6d", "7d", "8d", "9d", "10d", "Jd", "Qd", "Kd", "Ad" \
												)

	local iNumberOfDecks = 4	-- Number of decks in the shoe for the game.
	local CardShoe = #()			-- Holds a number of copies of CardDeckArray depending on the shoe size (iNumberOfDecks) set for the game
	local DiscardPile = #()		-- Array to hold the played cards

	-- definition of a player, including potential hands, score, and cash
	struct gambler
				(
					CardOrigin, \
					Hand1, \
					Hand2, \
					Hand1Cards, \
					Hand2Cards, \
					HandCount, \
					Hand1Score, \
					Hand2Score, \
					Hand1Wager, \
					Hand2Wager, \
					Hand1Chips, \
					Hand2Chips, \
					Cash
				)

	local Dealer = gambler	CardOrigin:[0,150,0] \
											Hand1:#() \
											Hand2:undefined \
											Hand1Cards:#() \
											Hand2Cards:undefined \
											HandCount:0 \
											Hand1Score:0 \
											Hand2Score:undefined \
											Hand1Wager:0 \
											Hand2Wager:undefined \
											Hand1Chips:#() \
											Hand2Chips:undefined \
											Cash:0

	local Player1 = gambler	CardOrigin:[-45,38,0] \
											Hand1:#() \
											Hand2:undefined \
											Hand1Cards:#() \
											Hand2Cards:undefined \
											HandCount:0 \
											Hand1Score:0 \
											Hand2Score:undefined \
											Hand1Wager:0 \
											Hand2Wager:undefined \
											Hand1Chips:#() \
											Hand2Chips:undefined \
											Cash:0

	local iCurrentHand = 0 -- Which of the players hand is currently being played
	local iInsurance = 0	-- Insurance bet against dealer BlackJack

	local iFirstPlayableHand = 1	-- First players hand to use when checking who wins.

	local sSettingsFile = (getDir #plugcfg) + "\\MaxJack.ini" -- program settings file

	local sDataDir = (getDir #userscripts) + "\\MaxJack\\"

	local iTickCount = 15			-- Interval for the timers.
	local iClockToUse = 1			-- Used to increment which timer is used inside of DealersTurn(). If multiple clocks aren't used then some cards get missed.
	local iCardXOffset = 0			-- X offset for the next card to display at the dealer's or player's hand
	local iCardYOffset = -15		-- Y offset for the next card to display at the dealer's or player's hand
	local iCardZOffset = 0.1		-- Z offset for the next card to display at the dealer's or player's hand


	local p3DealPoint = [166,223,0]				-- The location where the cards come off of the deck
	local DealRotation = eulerAngles 0 0 50	-- The angle of the card as it comes off of the deck

	local CardToMove1 = undefined						-- Card node to be moved by the timer event. One for each of the timer events available.
	local CardToMove2 = undefined
	local CardToMove3 = undefined
	local CardToMove4 = undefined
	local p3CardAnimStep1 = [0,0,0]					-- The offset to use while moving the cards (defaulted to 0). One for each of the timer events available.
	local p3CardAnimStep2 = [0,0,0]
	local p3CardAnimStep3 = [0,0,0]
	local p3CardAnimStep4 = [0,0,0]
	local CardRotationStep1 = eulerAngles 0 0 0	-- The rotation to use while moving the cards (defaulted to 0). One for each of the timer events available.
	local CardRotationStep2 = eulerAngles 0 0 0
	local CardRotationStep3 = eulerAngles 0 0 0
	local CardRotationStep4 = eulerAngles 0 0 0

	local bTrackBarState = trackBar.visible					-- Holds the state of the user's Trackbar when the script starts. Used to restore the UI when the script exits
	local bTimeSliderState = timeSlider.isVisible()			-- Holds the state of the user's TimeSlider when the script starts. Used to restore the UI when the script exits
	local bStatusPanelState = statusPanel.visible			-- Holds the state of the user's StatusPanel when the script starts. Used to restore the UI when the script exits.
	local sCurrentMenu = menuMan.getMenuFile()			-- Holds the name of the menu file that is active when MaxJack starts
	local bExpertMode = cui.getExpertMode()				-- Holds the state of the user's expert mode when the script starts. Used to restore the UI when the script exits

	local rltMaxJack							-- Interface rollout

	local bmpBetButtons = openBitMap (sDataDir + "BetButtons.bmp")
	local bmpPlayButtons = openBitMap (sDataDir + "PlayButtons.bmp")
	local bmpYesNoContinueButtons = openBitMap (sDataDir + "YesNoContinueButtons.bmp")
	local bmpControlBackground = openBitmap (sDataDir + "ControlBackground.bmp")

	local sMessageText = ""		-- Holds the strings to be passed to the custom messagebox and querybox controls
	local bQueryBoxResult = false		-- holds the return value (boolean) from the DrawQueryBox function.
   --*********************************************************************************************
	--FUNCTIONS
	--*********************************************************************************************
	fn Shuffle MyCardArray =
	(
		-- Shuffles an arbirtarily sized deck/shoe of cards a random number of times, no less than 7 and no more than 100.
		-- 7 because that is the statistically optimal # of shuffles to have a 52 card deck achieve randomness.
		-- 100 because I wanted to add some more randomness into the shuffle and that seemed like a good upper bound

		-- Clear the discard pile
		DiscardPile = #()

		iShuffleCount = random (7 * (MyCardArray.count / 52)) (100 * (MyCardArray.count / 52))

		rltMaxJack.lblStatus.text = "Shuffling..."
		for i = 1 to iShuffleCount do
		(
			-- Clear the ShuffledArray so we have a blank slate for each shuffle
			ShuffledArray = #()

			-- The shuffle count should equal the number of cards in the shoe when this function was called
			iCardCount = MyCardArray.count

			for j = 1 to iCardCount do
			(
				iSelection = random 1 (iCardCount - j)
				append ShuffledArray MyCardArray[iSelection]
				deleteItem MyCardArray iSelection
			)

			-- Cut the deck at a random point
			CutArray = #()

			iCutPoint = random 1 iCardCount -- The cut shoud be somewhere within the card count
			for i = iCutPoint to 1 by -1 do
			(
				append CutArray ShuffledArray[i]
				deleteItem ShuffledArray i
			)

			for card in CutArray do append ShuffledArray card

			-- Burn the top card at the end of the shuffle.
			-- Why? Because the casinos do it.
			append DiscardPile ShuffledArray[1]
			deleteItem ShuffledArray 1

			rltMaxJack.lblStatus.text = ""

			-- Return the shuffled and cut array
			return ShuffledArray
		)
	) --End of Function


	fn DrawCard CardArray bFaceUp sCardValue bHoleCard =
	(
		-- Creates a new plane to hold the card texture and then moves the card from the card shoe to the proper destination
		-- sName: String to use for card name	bFaceUp: t/f show the card face or back		sCardValue: Value of card to show
		-- bHoleCard: t/f if true then we're just turning the dealer's hole card over.

		iMaterialIndex = 1
		iCardRank = 1

		NewCard = rectangle width:36 length:50 corner_radius:2 mapcoords:true wirecolor:(color 255 255 255)
		convertToMesh NewCard
		addModifier NewCard (uvwmap())

		if not bHoleCard then
		(
			NewCard.position = p3DealPoint
			rot_obj = DealRotation
		)
		else
		(
			rot_obj = eulerAngles 0 0 0
			NewCard.position = Dealer.CardOrigin + [iCardXOffset,(Dealer.Hand1.count * iCardYOffset),(Dealer.Hand1.count * iCardZOffset)]
		)

		rotate NewCard rot_obj

		if bFaceUp != true then
		(
			iMaterialIndex = 5
			NewCard.material = meditmaterials[iMaterialIndex]
		)
		else
		(
			sCardSuit = subString sCardValue sCardValue.count 1

			local iMaterialIndex = undefined

			case sCardSuit of
			(
				"s":	iMaterialIndex = 1
				"c":	iMaterialIndex = 2
				"h":	iMaterialIndex = 3
				"d":	iMaterialIndex = 4
			)

			local sCardIndex = trimRight sCardValue "schd"

			case sCardIndex of
			(
				"J":			NewCard.material = meditMaterials[iMaterialIndex][10]
				"Q":			NewCard.material = meditMaterials[iMaterialIndex][11]
				"K":			NewCard.material = meditMaterials[iMaterialIndex][12]
				"A":			NewCard.material = meditMaterials[iMaterialIndex][13]
				default:	NewCard.material = meditMaterials[iMaterialIndex][(sCardIndex as integer) - 1]
			)
		)

		append CardArray NewCard

		clearSelection()
	)


	fn MoveCard MyCard p3MyDestination iWhichTimer =
	(
 		--Animates the card motion from it's deal point to the proper location on the table.

 		local p3Step = \
 			[((p3MyDestination.x - p3DealPoint.x) / iTickCount), ((p3MyDestination.y - p3DealPoint.y) / iTickCount), ((p3MyDestination.z - p3DealPoint.z) / iTickCount)]

  		local RotationStep = \
  			random (eulerAngles 0 0  (-1 * 50.0 / (iTickCount as float))) (eulerAngles 0 0 (-1 * 60.0 / (iTickCount as float)))

		case iWhichTimer of
 		(
	 		1:	(
		 			p3CardAnimStep1 = p3Step
					CardRotationStep1 = RotationStep

					CardToMove1 = MyCard

					rltMaxJack.tmrAnimClock1.ticks = 0
					rltMaxJack.tmrAnimClock1.active = true
	 			)

	 		2:	(
		 			p3CardAnimStep2 = p3Step
		 			CardRotationStep2 = RotationStep

					CardToMove2 = MyCard

					rltMaxJack.tmrAnimClock2.ticks = 0
					rltMaxJack.tmrAnimClock2.active = true
	 			)

	 		3:	(
		 			p3CardAnimStep3 = p3Step
		 			CardRotationStep3 = RotationStep

					CardToMove3 = MyCard

					rltMaxJack.tmrAnimClock3.ticks = 0
					rltMaxJack.tmrAnimClock3.active = true
	 			)

	 		4:	(
		 			p3CardAnimStep4 = p3Step
					CardRotationStep4 = RotationStep

					CardToMove4 = MyCard

					rltMaxJack.tmrAnimClock4.ticks = 0
					rltMaxJack.tmrAnimClock4.active = true
	 			)
 		)
	)


	fn FindCardValue MyCard =
	(
		-- Figures out the numeric value of a card.

		local sCardRank = trimRight MyCard "schd"

		case sCardRank of
		(
			"J":			return 10
			"Q":			return 10
			"K":			return 10
			"A":			return "A"
			default:	(return sCardRank as integer)
		)
	) --End of Function


	fn CalculateScore MyHand bAllowSoftAces =
	(
		-- Adds up the cards in a hand to find the point total. If bAllowSoftAces is true then aces can be 1 or 11.
		-- If bAllowSoftAces is false then Aces can only be 11 (for the Dealers)

		local ScoreArray = #() -- Holds the numeric value of each of the cards in MyHand
		local AceValueArray = #() -- Holds the assigned values for he various Aces in the hand
		local iAceCount = 0
		local iScore = 0	-- The integer value of all cards in the hand.

		for card in MyHand do
		(
			append ScoreArray (FindCardValue card)
		)


		-- If the dealer is dealt two aces on the initial deal then soft aces should be allowed.
		if ScoreArray.count == 2 then
		(
			if ScoreArray[1] == "A" and ScoreArray[2] == "A" then
			(
				bAllowSoftAces = true
			)
		)

		-- Calculate the score for non-Ace card by adding them sequentially.
		-- If an ace is found and soft-Aces aren't allowed then add 11 to the score.
		-- If soft-Aces are allowed don't add it to the score and set it aside for later use.
		for score in ScoreArray do
		(
			if score != "A" then
			(
				iScore += score as integer
			)
			else
			(
				if bAllowSoftAces == true then
				(
					iAceCount += 1
				)
				else
				(
					iScore += 11
				)
			)
		)

		-- The player's hand has one or more Aces in it. For each Ace check the score to see if the Ace should be scored as 1 or 11.
		for i = 1 to iAceCount do
		(
			if iScore + 11 <= 21 then
			(
				iScore += 11
				AceValueArray[i] = 11
			)
			else
			(
				-- Since the assigned value of any aces before the current  Ace could affect the score relative to this Ace
				-- try various permutations of 1 and/or 11, always striving to stay below 21
				iScore += 1
				AcevalueArray[i] = 1
			)

			-- Multiple Aces and the player has potentially busted.
			-- Start knocking each Ace down to a value of 1 to see if the score can be kept under 21
			if (iScore > 21) and  (i > 1) then
			(
				-- Take the aces back out of the score
				for AceValue in AceValueArray do
				(
					iScore -= AceValue
				)

				-- Set the previous Ace values to 1 and add them to the running total.
				for j = 1 to (i - 1) do
				(
					iScore += 1
					AceValueArray[j] = 1
				)

				-- Ok, the value of the cards is as low as possible.
				-- Check to see if the score can still be under 21 if the Ace is 11.
				-- If not make the Ace 1 and the total is what it is.
				if iScore + 11 <= 21 then
				(
					iScore += 11
					AceValueArray[i] = 11
				)
				else
				(
					iScore += 1
					AceValueArray[i] = 1
				)
			)
		)

		return iScore
	)


	fn UpdateDisplay bShowHoleCard iPlayingHand =
	(
		-- Update the display. if bShowHoleCard is true then the Dealer's down card is turned over.

		if bShowHoleCard == true then
		(
			-- Show the Dealer's hole graphic only if it hasn't already been flipped
			if $DealerHoleCard.material == meditmaterials[5] then
			(
				for i = Dealer.Hand1Cards.count to 1 by -1 do
				(
					if Dealer.Hand1Cards[i].name == "DealerHoleCard" then
					(
						deleteItem Dealer.Hand1Cards i
					)
				)

				delete $DealerHoleCard

				DrawCard Dealer.Hand1Cards true Dealer.Hand1[2] true
				Dealer.Hand1Cards[Dealer.Hand1Cards.count].name = "DealerHoleCard"
			)
		)
	)


	fn DrawScreenText =
	(
		-- Creates a game themed modal messagebox and uses the value in the global variable sMessageText as the display text.
		rollout rltMJMessageBox "MaxJack" width:180 height:100
		(
			label lblMessage "" pos:[10,10] width:170 height:48
			button btnContinue "Continue" pos:[50,60] width:80 height:24 images:#(bmpYesNoContinueButtons, "", 3, 3, 3, 3, 3)

			on rltMJMessageBox open do
			(
				lblMessage.text = sMessageText
			)

			on btnContinue pressed do
			(
				destroyDialog rltMJMessageBox
				sMessageText = ""
			)
		)

		createDialog rltMJMessageBox 180 100 style:#(#style_border) bgcolor:(color 0 100 1) fgcolor:white modal:true

		-- This code draws the message as screen text. It works, but causes synchronization issues with the timer UI controls.
--		local ScreenScaleFactor = getScreenScaleFactor [0,0,0]
--
--		MyText = text text:sMessageText wirecolor:red position:[0,0,0]
--		convertToMesh MyText
--
--		-- Transform the text to be orthogonal to the viewport
--		MyText.transform *= (inverse (getViewTM()))
--
--		MyText.position = [0,-25,25]
--
--		-- Scale the text to fit the viewport
--		local fWidth = MyText.max.x + (abs MyText.min.x)
--		ScreenScaleFactor /= fWidth
--
--		MyText.scale = [ScreenScaleFactor, ScreenScaleFactor, ScreenScaleFactor]
--
--		redrawViews()
--
--		-- Wait for the use to read the text
--		sleep 2
--
--		-- Delete the text
--		delete MyText
--		sMessageText = ""
	)


	fn DrawQueryBox =
	(
		-- Creates a game themed modal querybox and uses the value in the global variable sMessageText as the display text.
		rollout rltMJQueryBox "MaxJack" width:180 height:100
		(
			label lblMessage "" pos:[10,10] width:170 height:48
			button btnYes "Yes" pos:[6,60] width:80 height:24 images:#(bmpYesNoContinueButtons, "", 3, 1, 1, 1, 1)
			button btnNo "No" pos:[94,60] width:80 height:24 images:#(bmpYesNoContinueButtons, "", 3, 2, 2, 2, 2)

			on rltMJQueryBox open do
			(
				lblMessage.text = sMessageText
			)

			on btnYes pressed do
			(
				destroyDialog rltMJQueryBox
				sMessageText = ""
				bQueryBoxResult = true
			)

			on btnNo pressed do
			(
				destroyDialog rltMJQueryBox
				sMessageText = ""
				bQueryBoxResult = false
			)
		)

		createDialog rltMJQueryBox 180 100 style:#(#style_border) bgcolor:(color 0 100 1) fgcolor:white modal:true
	)


	fn DrawChips p3ChipOrigin iChipCount ChipArray ChipMaterial iBetOrPayout =
	(
		-- Draw new chip(s) on the table. Offset the chips by Y -17 from the current stack if the chips are part of a payout.
		-- iBetOrPayout controls the chip stack location. 1 = original bet. 2 = extra chips added to bet (double down or split.)
		-- 3 = payout chips, 4 = additional payout chips (for blackjack)

		case iBetOrPayout of
		(
			1:	p3ChipOrigin = p3ChipOrigin
			2:	p3ChipOrigin += [17, 0, 0]
			3:	p3ChipOrigin += [0,-17,0]
			4:	p3ChipOrigin += [0,-17, (ChipArray[ChipArray.count].pos.z + 1)]
			default: p3ChipOrigin = p3ChipOrigin
		)

		local NewChip = cylinder radius:8 height:1 segments:18 mapcoords:false wirecolor:(color 255 255 255)
		NewChip.position = (p3ChipOrigin + [(random -0.5 0.5), (random -0.5 0.5), 0])
		in coordsys local NewChip.rotation = (angleAxis (random 0.0 360.0) [0,0,1])
		convertToMesh NewChip
		addModifier NewChip (uvwmap())
		NewChip.material = ChipMaterial

		append ChipArray NewChip

		if iChipCount > 1 then
		(
			for i = 2 to iChipCount do
			(
				local NewCloneChip = copy NewChip
				NewCloneChip.position = (NewChip.position + [(random -0.5 0.5),(random -0.5 0.5), i])
				in coordsys local NewCloneChip.rotation = (angleAxis (random 0.0 360.0) [0,0,1])
				append ChipArray NewCloneChip
			)
		)

		clearSelection()
	)


	fn CalculatePayout iWager sEndState iHandNumber =
	(
		-- Based on the winner and the bet determine what payout (if any) is correct.
		local ChipBitArray = #{}

		case sEndState of
		(
			"Blackjack":	(
									local iPayout = iWager * 3 / 2
									local iNewChipsCount = 0
									Player1.Cash += iPayout

									--Figure out which chips to display

									-- $1000 chips
									local i1000 = iPayout / 1000
									if i1000 > 0 then
									(
										append ChipBitArray 1000
									)

									iPayout -= (1000 * i1000)
									iNewChipsCount += 1


									-- $500 chips
									local i500 = iPayout / 500
									if i500 > 0 then
									(
										append ChipBitArray 500
									)

									iPayout -= (500 * i500)
									iNewChipsCount += 1


									-- $100 chips
									local i100 = iPayout / 100
									if i100 > 0 then
									(
										append ChipBitArray 100
									)

									iPayout -= (100 * i100)
									iNewChipsCount += 1


									-- $50 chips
									local i50 = iPayout / 50
									if i50 > 0 then
									(
										append ChipBitArray 50
									)

									iPayout -= (50 * i50)
									iNewChipsCount += 1


									-- $10 chips
									local i10 = iPayout / 10
									if i10 > 0 then
									(
										append ChipBitArray 10
									)

									iPayout -= (10 * i10)
									iNewChipsCount += 1


									-- $5 chips
									local i5 = iPayout / 5
									if i5 > 0 then
									(
										append ChipBitArray 5
									)

									iPayout -= (5 * i5)
									iNewChipsCount += 1

									--Draw chips
									if iNewChipsCount > 0 then
									(
										case iHandNumber of
										(
											1:	(
													if ChipBitArray[1000] then
													(
														DrawChips Player1.Hand1Chips[1].position i1000 Player1.Hand1Chips meditMaterials[6][6] 3
													)

													if ChipBitArray[500] then
													(
														DrawChips Player1.Hand1Chips[1].position i500 Player1.Hand1Chips meditMaterials[6][5] 4
													)

													if ChipBitArray[100] then
													(
														DrawChips Player1.Hand1Chips[1].position i100 Player1.Hand1Chips meditMaterials[6][4] 4
													)

													if ChipBitArray[50] then
													(
														DrawChips Player1.Hand1Chips[1].position i50 Player1.Hand1Chips meditMaterials[6][3] 4
													)

													if ChipBitArray[10] then
													(
														DrawChips Player1.Hand1Chips[1].position i10 Player1.Hand1Chips meditMaterials[6][2] 4
													)

													if ChipBitArray[5] then
													(
														DrawChips Player1.Hand1Chips[1].position i5 Player1.Hand1Chips meditMaterials[6][1] 4
													)
												)

											2:	(
													if ChipBitArray[1000] then
													(
														DrawChips Player1.Hand2Chips[1].position i1000 Player1.Hand2Chips meditMaterials[6][6] 3
													)

													if ChipBitArray[500] then
													(
														DrawChips Player1.Hand2Chips[1].position i500 Player1.Hand2Chips meditMaterials[6][5] 4
													)

													if ChipBitArray[100] then
													(
														DrawChips Player1.Hand2Chips[1].position i100 Player1.Hand2Chips meditMaterials[6][4] 4
													)

													if ChipBitArray[50] then
													(
														DrawChips Player1.Hand2Chips[1].position i50 Player1.Hand2Chips meditMaterials[6][3] 4
													)

													if ChipBitArray[10] then
													(
														DrawChips Player1.Hand2Chips[1].position i10 Player1.Hand2Chips meditMaterials[6][2] 4
													)

													if ChipBitArray[5] then
													(
														DrawChips Player1.Hand2Chips[1].position i5 Player1.Hand2Chips meditMaterials[6][1] 3
													)
												)
										)
									)
								)
			"Win":			(
									Player1.Cash += (iWager * 2)
									(
										case iHandNumber of
										(
											1:	DrawChips Player1.Hand1Chips[1].position Player1.Hand1Chips.count Player1.Hand1Chips Player1.Hand1Chips[1].material 3
											2:	DrawChips Player1.Hand2Chips[1].position Player1.Hand2Chips.count Player1.Hand2Chips Player1.Hand2Chips[1].material 3
										)
									)

									redrawViews()
								)
			"Push":			(
									Player1.Cash += iWager
								)
			"Lose":			(
									Player1.Cash = Player1.Cash
								)
		)

		setINISetting sSettingsFile "Winnings" "Cash" (Player1.Cash as string)
		
		rltMaxJack.lblCash.text = ("$" + Player1.Cash as string)
	)


	fn ClearTable =
	(
		-- Put the Dealer's cards in the discard pile and clear his hand and score
		for Card in Dealer.Hand1 do
		(
			append DiscardPile Card
		)

		for Card in Dealer.Hand1Cards do
		(
			delete Card
		)

		Dealer.Hand1 = #()
		Dealer.Hand1Cards = #()
		Dealer.Hand1Score = 0

		-- Put the Player's cards in the discard pile and clear his hands and chips.
		for i = 1 to Player1.HandCount do
		(
			case i of
			(
				1:	(
							for Card in Player1.Hand1 do
							(
								append DiscardPile Card
							)

							for Card in Player1.Hand1Cards do
							(
								try
								(
									delete Card
								)
								catch()
							)

							for Chip in Player1.Hand1Chips do
							(
								try
								(
									delete Chip
								)
								catch()
							)

							Player1.Hand1 = #()
							Player1.Hand1Cards = #()
							Player1.Hand1Chips = #()
							Player1.Hand1Score = 0
					)
				2:	(
							for Card in Player1.Hand2 do
							(
								append DiscardPile Card
							)

							for Card in Player1.Hand2Cards do
							(
								try
								(
									delete Card
								)
								catch()
							)

							for Chip in Player1.Hand2Chips do
							(
								try
								(
									delete Chip
								)
								catch()
							)

							Player1.Hand2 = undefined
							Player1.Hand2Cards = #()
							Player1.Hand2Chips = undefined
							Player1.Hand2Score = undefined
					)
			)
		)

		Player1.HandCount = 0
		iCurrentHand = 0


		-- Reset the UI
		rltMaxJack.btnDeal.enabled = false
		rltMaxJack.btnHit.enabled = false
		rltMaxJack.btnStand.enabled = false
		rltMaxJack.btnDoubleDown.enabled = false
		rltMaxJack.btnSplit.enabled = false
		
		rltMaxJack.btn50.enabled = false
		rltMaxJack.btn100.enabled = false
		rltMaxJack.btn500.enabled = false
		rltMaxJack.btn1000.enabled = false
		rltMaxJack.btn5000.enabled = false
		rltMaxJack.lblStatus.text = ""

		if Player1.Cash > 0 then
		(
			rltMaxJack.btn5.enabled = true
			
			if Player1.Cash >= 50 then
			(
				rltMaxJack.btn50.enabled = true
			)

			if Player1.Cash >= 100 then
			(
				rltMaxJack.btn100.enabled = true
			)

			if Player1.Cash >= 500 then
			(
				rltMaxJack.btn500.enabled = true
			)

			if Player1.Cash >= 1000 then
			(
				rltMaxJack.btn1000.enabled = true
			)

			if Player1.Cash >= 5000 then
			(
				rltMaxJack.btn5000.enabled = true
			)

			Player1.Hand1Wager = 0
			Player1.Hand2Wager = undefined

			rltMaxJack.lblWager.text = ("$" + Player1.Hand1Wager as string)
		)
		else
		(
			sMessageText = "You're flat broke.\r\nWould you like a loan from the house?"
			DrawQueryBox()
			if bQueryBoxResult then
			(
				Player1.Cash = 25000

				rltMaxJack.btn5.enabled = true
				rltMaxJack.btn50.enabled = true
				rltMaxJack.btn100.enabled = true
				rltMaxJack.btn500.enabled = true
				rltMaxjack.btn1000.enabled = true
				rltMaxJack.btn5000.enabled = true
				rltMaxJack.btnDeal.enabled = true

				rltMaxJack.btnDoubleDown.enabled = false
				rltMaxJack.btnHit.enabled = false
				rltMaxJack.btnSplit.enabled = false
				rltMaxJack.btnStand.enabled = false
			)
			else
			(
				sMessageText = "Thanks for playing."
				DrawScreenText() --"Thanks for playing."

				destroyDialog rltMaxJack
			)
		)
	)


	fn DealersTurn bShowHoleCard =
	(
		-- Logic for when it is the Dealer's turn

		iClockToUse += 1

		if iClockToUse > 4 then
		(
			iClockToUse = 1
		)

		UpdateDisplay true 0

		rltMaxJack.lblStatus.text = "Dealer's turn"

		if bShowHoleCard == true then
		(
			-- Turn the hole card over only if it hasn't already been flipped
			if $DealerHoleCard.material == meditmaterials[5] then
			(
				delete $DealerHoleCard
				DrawCard Dealer.Hand1Cards true Dealer.Hand1[2] true
			)
		)

		Dealer.Hand1Score = CalculateScore Dealer.Hand1 false

		if Dealer.Hand1Score > 21 then
		(
			for i = 1 to Player1.HandCount do
			(
				case i of
				(
					1:	(
							if Player1.Hand1Score != 0 then
							(
								CalculatePayout Player1.Hand1Wager "Win" i

								sMessageText =  ("Dealer busted.\r\nYou win $" + (Player1.Hand1Wager as string) + " on hand " + (i as string) + ".")
								DrawScreenText()
							)
						)
					2:	(
							if Player1.Hand2Score != 0 then
							(
								CalculatePayout Player1.Hand2Wager "Win" i

								sMessageText = ("Dealer busted.\r\nYou win $" + (Player1.Hand2Wager as string) + " on hand " + (i as string) + ".")
								DrawScreenText()
							)
						)
				)
			)

			ClearTable()
		)
		else
		(
			case of
			(
				--Dealer has to hit. Take another card.
				(Dealer.Hand1Score <= 16):	(
																	append Dealer.Hand1 CardShoe[1]
																	deleteItem CardShoe 1

																	DrawCard Dealer.Hand1Cards true Dealer.Hand1[Dealer.Hand1.count] false
																	MoveCard Dealer.Hand1Cards[Dealer.Hand1Cards.count] (Dealer.CardOrigin + [(iCardXOffset * (Dealer.Hand1.count - 1)), (Dealer.Hand1.count * iCardYOffset), (Dealer.Hand1.count * iCardZOffset)]) iClockToUse

																	Dealer.Hand1Score = CalculateScore Dealer.Hand1 true
																	UpdateDisplay true 0

																	DealersTurn false
																)

				--Dealer has to stand. Calculate the scores and payout.
				(Dealer.Hand1Score >= 17):	(
															rltMaxJack.lblStatus.text = ""

															for i = iFirstPlayableHand to Player1.HandCount do
															(
																case i of
																(
																	1:	(
																			if Player1.Hand1Score > 0 then -- a zero score means the hand was busted.
																			(
																				UpdateDisplay true 1

																				if Dealer.Hand1Score > Player1.Hand1Score then
																				(
																					CalculatePayout Player1.Hand1Wager "Lose" 1

																					sMessageText =  ("Dealer wins with " + (Dealer.Hand1Score as string) + ".\r\nYou lose $" + (Player1.Hand1Wager as string) + " on hand 1.")
																					DrawScreenText()
																				)
																				else
																				(
																					if Dealer.Hand1Score == Player1.Hand1Score then
																					(
																						CalculatePayout Player1.Hand1Wager "Push" 1

																						sMessageText = ("Push.\r\nYou get your wager of $" + (Player1.Hand1Wager as string) + " returned to you on hand 1.")
																						DrawScreenText()
																					)
																					else
																					(
																						CalculatePayout Player1.Hand1Wager "Win" 1

																						sMessageText = ("Player wins with " + (Player1.Hand1Score as string) + "!\r\nYou win $" + (Player1.Hand1Wager as string) + " on hand 1.")
																						DrawScreenText()
																					)
																				)
																			)
																		)
																 2:	(
																			if Player1.Hand2Score > 0 then -- a zero score means the hand was busted.
																			(
																				UpdateDisplay true 2

																				if Dealer.Hand1Score > Player1.Hand2Score then
																				(
																					CalculatePayout Player1.Hand2Wager "Lose" 2

																					sMessageText = ("Dealer wins with " + (Dealer.Hand1Score as string) + ".\r\nYou lose $" + (Player1.Hand2Wager as string) + " on hand 2.")
																					DrawScreenText()
																				)
																				else
																				(
																					if Dealer.Hand1Score == Player1.Hand2Score then
																					(
																						CalculatePayout Player1.Hand2Wager "Push" 2

																						sMessageText = ("Push.\r\nYou get your wager of $" + (Player1.Hand2Wager as string) + " returned to you on hand 2.")
																						DrawScreenText()
																					)
																					else
																					(
																						CalculatePayout Player1.Hand2Wager "Win"  2

																						sMessageText = ("Player wins with " + (Player1.Hand2Score as string) + "!\r\nYou win $" + (Player1.Hand2Wager as string) + " on hand 2.")
																						DrawScreenText()
																					)
																				)
																			)
																		)
															)
														)

														ClearTable()
													)
			)
		)
	)


	fn MakeBet Player Bet =
	(
		-- Adjust the wager and cash readouts for the provided player and the betting button that was clicked

		--Put the current wager back into the players bankroll. We're changing Bets, not adding to the current Bet.
		Player.Cash += Player1.Hand1Wager

		if Player.Cash >= Bet then
		(
			Player1.Hand1Wager = Bet
		)
		else
		(
			Player1.Hand1Wager = Player.Cash
		)

		Player.Cash -= Player1.Hand1Wager

		--Clear the unwanted bet chips from the table
		if Player1.Hand1Chips.count > 0 then
		(
			for Chip in Player1.Hand1Chips do
			(
				delete Chip
			)
		)

		Player1.Hand1Chips = #()

		local p3ChipOrigin = [(random -0.5 0.5), (random -0.5 0.5), 0]

		case Bet of
		(
			5:			DrawChips p3ChipOrigin 1 Player1.Hand1Chips meditMaterials[6][1] 1
			50:		DrawChips p3ChipOrigin 1 Player1.Hand1Chips meditMaterials[6][3] 1
			100:		DrawChips p3ChipOrigin 2 Player1.Hand1Chips meditMaterials[6][3] 1
			500:		DrawChips p3ChipOrigin 5 Player1.Hand1Chips meditMaterials[6][4] 1
			1000:	DrawChips p3ChipOrigin 2 Player1.Hand1Chips meditMaterials[6][5] 1
			5000:	DrawChips p3ChipOrigin 5 Player1.Hand1Chips meditMaterials[6][6] 1
		)

		rltMaxJack.btnDeal.enabled = true
		
		rltMaxJack.lblWager.text = ("$" + Player1.Hand1Wager as string)
		rltMaxJack.lblCash.text = ("$" + Player.Cash as string)
	)


	fn CheckForSplit MyHand MyCash MyWager =
	(
		-- Check the hand to see if a split if valid
		rltMaxJack.btnSplit.enabled = false

		if ((trimRight MyHand[1] "schd") == (trimRight MyHand[2] "schd")) and (MyCash >= MyWager) then
		(
			rltMaxJack.btnSplit.enabled = true
		)
		else
		(
			rltMaxJack.btnSplit.enabled = false
		)
	)


	fn CheckHandTotal MyHandScore MyWager =
	(
		-- Function used when the player hits to see if they busted or not

		if MyHandScore < 21 then
		(
			rltMaxJack.btnHit.enabled = true
			rltMaxJack.btnStand.enabled = true
		)
		else
		(
			if MyHandScore > 21 then
			(
				CalculatePayout MyWager "Lose" iCurrentHand

				sMessageText = ("BUST!\r\nYou lose $" + (MyWager as string) + " on hand " + (iCurrentHand as string) + ".")
				DrawScreenText()

				-- Move the cards from the proper hand to the discard pile
				case iCurrentHand of
				(
					1:	(
							for card in Player1.Hand1 do
							(
								append DiscardPile card
							)

							Player1.Hand1 = #()
							Player1.Hand1Score = 0
						)
					2:	(
							for card in Player1.Hand2 do
							(
								append DiscardPile card
							)

							Player1.Hand2 = #()
							Player1.Hand2Score = 0
						)
				)

				-- If this is the only player's hand then the table should be cleared. If it's one of multiple
				-- Players hands then play should move either to the next player hand or to the dealer.
				if iCurrentHand == Player1.HandCount then
				(
					rltMaxJack.btnHit.enabled = false
					rltMaxJack.btnStand.enabled = false

					if Player1.HandCount > 1 then
					(
						DealersTurn false
					)
					else
					(
						ClearTable()
					)
				)
				else
				(
					--Set up the UI and move to the next hand
					rltMaxJack.btnHit.enabled = true
					rltMaxJack.btnStand.enabled = true
					iCurrentHand += 1
					UpdateDisplay false iCurrentHand
					rltMaxJack.lblStatus.text = "Playing Hand #" + (iCurrentHand as string)
					CheckForSplit Player1.Hand1 Player1.Cash Player1.Hand1Wager
				)
			)
		)
	)


	fn RestoreMaxAndQuit =
	(
		clearListener()

		if bExpertMode then
		(
			cui.expertModeOn()
		)
		else
		(
			cui.expertModeOff()
		)

		try
		(
			trackBar.visible = bTrackBarState
		)
		catch
		(
			trackBar.visible = true
		)

		try
		(
			timeSlider.setVisible bTimeSliderState
		)
		catch
		(
			timeSlider.setVisible true
		)

		statusPanel.visible = bStatusPanelState

		try
		(
			menuMan.loadMenuFile sCurrentMenu
		)
		catch
		(
			menuMan.loadMenuFile "DefaultUI.mnu"
		)

		hideByCategory.lights = false

		fetchMaxFile quiet:true
	)


	--*********************************************************************************************
	--USER INTERFACE CONTROLS
	--*********************************************************************************************
	rollout rltMaxJack "MaxJack" width:464 height:170
	(
		--groupBox grpPlay "" pos:[8,0] width:448 height:48
			button btnDeal "Deal" pos:[16,16] width:80 height:24 images:#(bmpPlayButtons, "", 11, 1, 1, 7, 7) enabled:false
			button btnHit "Hit" pos:[104,16] width:80 height:24 images:#(bmpPlayButtons, "", 11, 2, 2, 8, 8) enabled:false
			button btnStand "Stand" pos:[192,16] width:80 height:24 images:#(bmpPlayButtons, "", 11, 3, 3, 9, 9) enabled:false
			button btnDoubleDown "DoubleDown" pos:[280,16] width:80 height:24 images:#(bmpPlayButtons, "", 11, 4, 4, 10, 10) enabled:false
			button btnSplit "Split" pos:[368,16] width:80 height:24 images:#(bmpPlayButtons, "", 11, 5, 5, 11, 11) enabled:false
		--groupBox grpWager "" pos:[200,48] width:256 height:89
			label lblCashLabel "Cash:" pos:[340,48] width:40 height:16
			label lblCash "$0" pos:[385,48] width:70 height:16
			label lblWagerLabel "Wager:" pos:[340,70] width:40 height:16
			label lblWager "$0" pos:[385,70] width:70 height:16
			button btn5 "$5" pos:[206,100] width:32 height:32 images:#(bmpBetButtons, "", 12, 1, 1, 7, 7) tooltip:"Bet $5"
			button btn50 "$50" pos:[248,100] width:32 height:32 images:#(bmpBetButtons, "", 12, 2, 2, 8, 8) tooltip:"Bet $50"
			button btn100 "$100" pos:[290,100] width:32 height:32 images:#(bmpBetButtons, "", 12, 3, 3, 9, 9) tooltip:"Bet $100"
			button btn500 "$500" pos:[332,100] width:32 height:32 images:#(bmpBetButtons, "", 12, 4, 4, 10, 10) tooltip:"Bet $500"
			button btn1000 "$1000" pos:[374,100] width:32 height:32 images:#(bmpBetButtons, "", 12, 5, 5, 11, 11) tooltip:"Bet $1000"
			button btn5000 "$5000" pos:[416,100] width:32 height:32 images:#(bmpBetButtons, "", 12, 6, 6, 12, 12) tooltip:"Bet $5000"
		label lblStatus "" pos:[8,56] width:190 height:80
		button btnQuit "Quit" pos:[416,145] width:40 height:20 images:#(bmpPlayButtons, "", 11, 6, 6, 6, 6)
		timer tmrAnimClock1 "AnimClock1" interval:0.3 active:false
		timer tmrAnimClock2 "AnimClock2" interval:0.3 active:false
		timer tmrAnimClock3 "AnimClock3" interval:0.3 active:false
		timer tmrAnimClock4 "AnimClock4" interval:0.3 active:false

		on tmrAnimClock1 tick do
		(
			try
			(
				if tmrAnimClock1.ticks <= iTickCount then
				(
					CardToMove1.position += p3CardAnimStep1
					rotate CardToMove1 CardRotationStep1
				)
			)
			catch()
		)

		on tmrAnimClock2 tick do
		(
			try
			(
				if tmrAnimClock2.ticks > iTickCount and tmrAnimClock2.Ticks <= (iTickCount * 2) then
				(
					CardToMove2.position += p3CardAnimStep2
					rotate CardToMove2 CardRotationStep2
				)
			)
			catch()
		)

		on tmrAnimClock3 tick do
			try
			(
				if tmrAnimClock3.ticks > (iTickCount * 2) and tmrAnimClock3.Ticks <= (iTickCount * 3) then
				(
					CardToMove3.position += p3CardAnimStep3
					rotate CardToMove3 CardRotationStep3
				)
			)
			catch()

		on tmrAnimClock4 tick do
		(
			try
			(
				if tmrAnimClock4.ticks > (iTickCount * 3) and tmrAnimClock4.Ticks <= (iTickCount * 4) then
				(
					CardToMove4.position += p3CardAnimStep4
					rotate CardToMove4 CardRotationStep4
				)
			)
			catch()
		)

		on btnDeal pressed do
		(
			-- Lock the UI so incorrect buttons can't be pressed
			btnDeal.enabled = false
			btnHit.enabled = false
			btnDoubleDown.enabled = false
			btnSplit.enabled = false
			btnStand.enabled = false
			btn5.enabled = false
			btn50.enabled = false
			btn100.enabled = false
			btn500.enabled = false
			btn1000.enabled = false
			btn5000.enabled = false

			--Set up the hand counters
			Dealer.HandCount = 1
			Player1.HandCount = 1
			iCurrentHand = 1
			iFirstPlayableHand = 1
			rltMaxJack.lblStatus.text = "Playing Hand #" + (iCurrentHand as string)

			-- Shuffle if there aren't enough cards to play a hand.
			if CardShoe.count <= 10 then
			(
				for card in CardShoe do
				(
					append DiscardPile card
				)

				CardShoe = #()
				CardShoe = Shuffle DiscardPile
			)

			 -- Deal the hand
			for i = 1 to 2 do
			(
				append Player1.Hand1 CardShoe[1]
				deleteItem CardShoe 1
				DrawCard Player1.Hand1Cards true Player1.Hand1[i] false
				MoveCard Player1.Hand1Cards[Player1.Hand1Cards.count] (Player1.CardOrigin + [((Player1.Hand1.count - 1) * iCardXOffset), \
					(Player1.Hand1.count * iCardYOffset), (Player1.Hand1.count * iCardZOffset)]) ((i * 2) - 1)

				append Dealer.Hand1 CardShoe[1]
				deleteItem CardShoe 1

				if i == 1 then
				(
					DrawCard Dealer.Hand1Cards true Dealer.Hand1[i] false
				)
				else
				(
					DrawCard Dealer.Hand1Cards false Dealer.Hand1[i] false
					Dealer.Hand1Cards[Dealer.Hand1Cards.count].name = "DealerHoleCard"
				)

				MoveCard Dealer.Hand1Cards[Dealer.Hand1Cards.count] (Dealer.CardOrigin + [((Dealer.Hand1.count - 1) * iCardXOffset), \
					(Dealer.Hand1.count * iCardYOffset) ,(Dealer.Hand1.count * iCardZOffset)]) (i * 2)
			)

			--Calculate scores. true/false controls whether soft-aces are allowed or not.
			Player1.Hand1Score = CalculateScore Player1.Hand1 true

			-- The Dealer should be calculated only on the up-card so the player doesn't know his true total
			Dealer.Hand1Score = FindCardValue Dealer.Hand1[1]

			if Dealer.Hand1Score == "A" then
			(
				Dealer.Hand1Score = 11
				UpdateDisplay false iCurrentHand

				iInsurance = 0

				if Player1.Cash >= 100 then
				(
					sMessageText = "Would you like insurance?"
					DrawQueryBox()
					if bQueryBoxResult then
					(
						iInsurance = 100

						Player1.Cash -= iInsurance
						lblCash.text = ("$" + (Player1.Cash as string))
					)
				)
			)

			-- Show the dealt cards, keeping the dealers hole card down
			UpdateDisplay false iCurrentHand

			-- Calculate the true Dealer's score (both cards) so the hand can be checked for Blackjacks
			iDealersTrueScore = CalculateScore Dealer.Hand1 false

			--Does the Dealer have Blackjack?
			if iDealersTrueScore == 21 then
			(
				Dealer.Hand1Score = iDealersTrueScore
				UpdateDisplay true iCurrentHand

				if Dealer.Hand1Score > Player1.Hand1Score then
				(
					-- Player is insured
					if iInsurance > 0 then
					(
						-- Payout the Insurance
						Player1.Cash += (iInsurance + Player1.Hand1Wager)
						
						sMessageText = ("Dealer has Blackjack. Insurance pays back $" + ((iInsurance + Player1.Hand1Wager) as string) + ".")
						DrawScreenText()

						iInsurance = 0
						
						lblCash.text = ("$" + (Player1.Cash as string))
					)
					else
					(
						-- Dealer doesn't have Blackjack.
						CalculatePayout Player1.Hand1Wager "Lose" iCurrentHand

						sMessageText = ("Dealer has Blackjack.\r\nYou lose $" + (Player1.Hand1Wager as string) + " on hand " + (iCurrentHand as string) + ".")
						DrawScreenText()
					)

				)
				else
				(
					if Dealer.Hand1Score == Player1.Hand1Score then
					(
						CalculatePayout Player1.Hand1Wager "Push" iCurrentHand

						sMessageText = ("Push.\r\nYou get your wager of $" + (Player1.Hand1Wager as string) + " returned to you on hand " + (iCurrentHand as string) + ".")
						DrawScreenText()
					)
				)

				ClearTable()
			)
			else
			(
				-- Does the Player have Blackjack?
				if Player1.Hand1Score == 21 then
				(
					UpdateDisplay true iCurrentHand

					CalculatePayout Player1.Hand1Wager "Blackjack" iCurrentHand

					sMessageText = ("Blackjack!\r\nYou win $" + ((Player1.Hand1Wager * 3 / 2) as string) + " on hand " + (iCurrentHand as string) + ".")
					DrawScreenText()

					if iCurrentHand == Player1.HandCount then
					(
						ClearTable()
					)
					else
					(
						iCurrentHand += 1
					)
				)
				else -- No Blackjacks. Play the hand through.
				(
					-- Take the insurance money
					iInsurance = 0

					UpdateDisplay false iCurrentHand

					-- Set the UI buttons for hand play
					rltMaxJack.btnHit.enabled = true
					rltMaxJack.btnStand.enabled = true

					CheckForSplit Player1.Hand1 Player1.Cash Player1.Hand1Wager

					-- Allow doubling down on the initial deal
					if Player1.Cash >= Player1.Hand1Wager then
					(
						rltMaxJack.btnDoubleDown.enabled = true
					)
					else
					(
						rltMaxJack.btnDoubleDown.enabled = false
					)
				)
			)
		)

		on btnHit pressed do
		(
			-- Disable the options that are only available on the initial deal
			btnDeal.enabled = false
			btnDoubleDown.enabled = false
			btnSplit.enabled = false

			case iCurrentHand of
			(
				1:	(
						-- Add a card to the Player
						append Player1.Hand1 CardShoe[1]
						deleteItem CardShoe 1

						DrawCard Player1.Hand1Cards true Player1.Hand1[Player1.Hand1.count] false
						MoveCard Player1.Hand1Cards[Player1.Hand1Cards.count] (Player1.CardOrigin + [(iCardXOffset * (Player1.Hand1.count - 1)), \
							(Player1.Hand1.count * iCardYOffset), (Player1.Hand1.count * iCardZOffset)]) 1

						Player1.Hand1Score = CalculateScore Player1.Hand1 true
						UpdateDisplay false iCurrentHand
						CheckHandTotal Player1.Hand1Score Player1.Hand1Wager
					)
				2:	(
						-- Add a card to the Player
						append Player1.Hand2 CardShoe[1]
						deleteItem CardShoe 1

						DrawCard Player1.Hand2Cards true Player1.Hand2[Player1.Hand2.count] false
						MoveCard Player1.Hand2Cards[Player1.Hand2Cards.count] [((Player1.CardOrigin.x * -1) + (iCardXOffset * (Player1.Hand2.count - 1))), \
							(Player1.CardOrigin.y + (Player1.Hand2.count * iCardYOffset)), (Player1.CardOrigin.z + (Player1.Hand2.count * iCardZOffset))] 1

						Player1.Hand2Score = CalculateScore Player1.Hand2 true
						UpdateDisplay false iCurrentHand
						CheckHandTotal Player1.Hand2Score Player1.Hand2Wager
					)
			)
		)

		on btnStand pressed do
		(
			case iCurrentHand of
			(
				1:	(
						Player1.Hand1Score = CalculateScore Player1.Hand1 true
					)
				2: (
						Player1.Hand2Score = CalculateScore Player1.Hand2 true
					)
			)

			if iCurrentHand == Player1.HandCount then --It's the dealer's turn
			(
				btnDeal.enabled = false
				btnHit.enabled = false
				btnDoubleDown.enabled = false
				btnSplit.enabled = false
				btnStand.enabled = false

				rltMaxJack.lblStatus.text = "Dealer's turn"
				UpdateDisplay true 0

				Dealer.Hand1Score = CalculateScore Dealer.Hand1 false
				UpdateDisplay true 0

				DealersTurn true
			)
			else -- multiple hands, move on.
			(
				if Player1.HandCount > 1 then
				(
					iCurrentHand += 1
					rltMaxJack.lblStatus.text = "Playing Hand #" + (iCurrentHand as string)
					UpdateDisplay false iCurrentHand
				)
			)
		)

		on btnDoubleDown pressed do
		(
			if iCurrentHand == 1 then -- DoubleDown is only valid on the intial hand
			(
				btnDeal.enabled = false
				btnHit.enabled = false
				btnStand.enabled = false
				btnDoubleDown.enabled = false
				btnSplit.enabled = false

				-- Register the bet increase
				if Player1.Cash >= Player1.Hand1Wager then
				(
					Player1.Cash -= Player1.Hand1Wager
					Player1.Hand1Wager *= 2
				)
				else
				(
					Player1.Hand1Wager += Player1.Cash
					Player1.Cash = 0
				)

				--Put more chips on the table
				DrawChips Player1.Hand1Chips[1].position Player1.Hand1Chips.count Player1.Hand1Chips Player1.Hand1Chips[1].material 2

				--Deal the one card the player gets
				append Player1.Hand1 CardShoe[1]
				deleteItem CardShoe 1

				DrawCard Player1.Hand1Cards true Player1.Hand1[Player1.Hand1.count] false
				MoveCard Player1.Hand1Cards[Player1.Hand1Cards.count] (Player1.CardOrigin + [(iCardXOffset * (Player1.Hand1.count - 1)), \
					(Player1.Hand1.count * iCardYOffset), (Player1.Hand1.count * iCardZOffset)]) 1

				Player1.Hand1Score = CalculateScore Player1.Hand1 true

				UpdateDisplay false iCurrentHand

				if Player1.Hand1Score <= 21 then
				(
					UpdateDisplay true 0

					Dealer.Hand1Score = CalculateScore Dealer.Hand1 false
					UpdateDisplay true 0

					DealersTurn true
				)
				else
				(
					for i = 1 to Player1.HandCount do
					(
						case i of
						(
							1:	(
									CalculatePayout Player1.Hand1Wager "Lose" i

									sMessageText = ("BUST!\r\nYou lose $" + (Player1.Hand1Wager as string) + " on hand " + (iCurrentHand as string) + ".")
									DrawScreenText()
								)
							2:	(
									CalculatePayout Player1.Hand2Wager "Lose" i

									sMessageText = ("BUST!\r\nYou lose $" + (Player1.Hand2Wager as string) + " on hand " + (iCurrentHand as string) + ".")
									DrawScreenText()
								)
						)
					)

					ClearTable()
				)
				
				rltMaxJack.lblCash.text = ("$" + Player1.Cash as string)
				rltMaxJack.lblWager.text = ("$" + Player1.Hand1Wager as string)
			)
		)

		on btnSplit pressed do
		(
			-- Increment the hand count
			Player1.HandCount += 1

			-- Don't check for the case of 1, because there will always be a hand 1 if we are splitting
			for i = 2 to Player1.HandCount do
			(
				bUpdate = false

				case i of
				(
					2:	(
							--If there is a score the hand already exists, move on.
							if Player1.Hand2Score == undefined then
							(
								-- Make new wager. Take amount equal to the Wager1 or the remainder of the player's money.
								if Player1.Cash >= Player1.Hand1Wager then
								(
									Player1.Hand2Wager = Player1.Hand1Wager
								)
								else
								(
									Player1.Hand2Wager = Player1.Cash
								)

								Player1.Cash -= Player1.Hand2Wager

								--Add more chips to the table
								Player1.Hand2Chips = #()
								DrawChips Player1.Hand1Chips[1].position Player1.Hand1Chips.count Player1.Hand2Chips Player1.Hand1Chips[1].material 2


								--Split the hand
								Player1.Hand2 = #()
								Player1.Hand2Cards = #()

								append Player1.Hand2 Player1.Hand1[2]
								deleteItem Player1.Hand1 2

								append Player1.Hand2Cards Player1.Hand1Cards[2]
								deleteItem Player1.Hand1Cards 2

								-- Move the second card from the first hand over to the new second hand (as the first card)
								Player1.Hand2Cards[1].position = [(Player1.CardOrigin.x * -1), Player1.Hand1Cards[1].pos.y, Player1.Hand1Cards[1].pos.z]

								-- Deal a new second card for Hand1
								append Player1.Hand1 CardShoe[1]
								deleteItem CardShoe 1
								DrawCard Player1.Hand1Cards true Player1.Hand1[Player1.Hand1.count] false
								MoveCard Player1.Hand1Cards[Player1.Hand1Cards.count] (Player1.CardOrigin + [((Player1.Hand1.count - 1) * iCardXOffset), \
									(Player1.Hand1.count * iCardYOffset),(Player1.Hand1.count * iCardZOffset)]) 1

								-- Deal a new second card for Hand2
								append Player1.Hand2 CardShoe[1]
								deleteItem CardShoe 1
								DrawCard Player1.Hand2Cards true Player1.Hand2[Player1.Hand2.count] false
								MoveCard Player1.Hand2Cards[Player1.Hand2Cards.count] [((Player1.CardOrigin.x * -1) + (Player1.Hand2.count - 1) * iCardXOffset), \
									(Player1.CardOrigin.y + (Player1.Hand2.count * iCardYOffset)), (Player1.CardOrigin.z + (Player1.Hand2.count * iCardZOffset))] 2

								Player1.Hand1Score = CalculateScore Player1.Hand1 true

								-- Check for blackjack on hand #1
								if Player1.Hand1Score == 21 then
								(
									CalculatePayout Player1.Hand1Wager "Blackjack" iCurrentHand

									sMessageText = ("BLACKJACK!\r\nYou win $" + ((Player1.Hand1Wager * 3 / 2) as string) + " on hand " + (iCurrentHand as string) + ".")
									DrawScreenText()

									iCurrentHand += 1
									iFirstPlayableHand += 1
									rltMaxJack.lblStatus.text = "Playing Hand #" + (iCurrentHand as string)

									for Card in Player1.Hand1 do
									(
										append DiscardPile Card
									)

									for Card in Player1.Hand1Cards do
									(
										delete Card
									)

									for Chip in Player1.Hand1Chips do
									(
										delete Chip
									)

									Player1.Hand1 = #()
									Player1.Hand1Score = 0

									UpdateDisplay false iCurrentHand
								)

								Player1.Hand2Score = CalculateScore Player1.Hand2 true

								if Player1.Hand2Score == 21 then
								(
									CalculatePayout Player1.Hand1Wager "Blackjack" 2

									sMessageText = ("BLACKJACK!\r\nYou win $" + ((Player1.Hand1Wager * 3 / 2) as string) + " on hand 2.")
									DrawScreenText()

									if Player1.Hand1Score == 0 then
									(
										UpdateDisplay false iCurrentHand
										ClearTable()
									)
									else
									(
										for Card in Player1.Hand2 do
										(
											append DiscardPile Card
										)

										for Card in Player1.Hand2Cards do
										(
											delete Card
										)

										for Chip in Player1.Hand2Chips do
										(
											delete Chip
										)

										Player1.Hand2 = #()
										Player1.Hand2Score = 0
										Player1.HandCount = 1

										UpdateDisplay false iCurrentHand
									)
								)

								bUpdate = true
							)
						)
				)

				if bUpdate == true then
				(
					btnDoubleDown.enabled = false
					btnSplit.enabled = false

					UpdateDisplay false iCurrentHand
					
					rltMaxJack.lblCash.text = ("$" + (Player1.Cash as string))
				)
			)
		)

		on btn5 pressed do
		(
			if Player1.Cash >= 5 then
			(
				MakeBet Player1 5
			) else (
				if (Player1.Cash >= 0) and (Player1.Cash < 5) then
				(
					MakeBet Player1 Player1.cash
				)
			)
		)

		on btn50 pressed do
		(
			MakeBet Player1 50
		)

		on btn100 pressed do
		(
			MakeBet Player1 100
		)

		on btn500 pressed do
		(
			MakeBet Player1 500
		)

		on btn1000 pressed do
		(
			MakeBet Player1 1000
		)

		on btn5000 pressed do
		(
			MakeBet Player1 5000
		)

		on btnQuit pressed do
		(
			sMessageText = "Quit MaxJack?"
			DrawQueryBox()
			if bQueryBoxResult then
			(
				destroyDialog rltMaxJack
			)
		)

		on rltMaxJack close do
		(
			RestoreMaxAndQuit()
		)
	)

	rollout rltTitle "Title" width:512 height:384
	(
		label lblFeedback "" pos:[10,364] align:#left
	)



	--*********************************************************************************************
	--MAIN
	--*********************************************************************************************
	try
	(
		local bmpTitle = openBitMap (sDataDir + "Title.jpg")

		createDialog rltTitle width:512 height:384 style:#(#style_border) bitmap:bmpTitle

		--Hold the current scene and configure the viewports to be correct for the game
		rltTitle.lblFeedback.text = "Holding the current Max scene..."
		holdMaxFile()

		rltTitle.lblFeedback.text = "Deleting existing objects..."
		for obj in objects do
		(
			delete obj
		)

		rltTitle.lblFeedback.text = "Hiding lights..."
		hideByCategory.none()
		hideByCategory.lights = true

		-- Go to fullscreen
		rltTitle.lblFeedback.text = "Setting display to fullscreen...."
		viewport.setLayout #layout_1

		viewport.setGridVisibility #all false
		try
		(
			rltTitle.lblFeedback.text = "Setting the viewport to smooth shading with highlights..."
			viewport.SetRenderLevel #smoothhighlights
		)
		catch()

		try
		(
			rltTitle.lblFeedback.text = "Turning off face edge display..."
			viewport.SetShowEdgeFaces false
		)
		catch()

		try
		(
			rltTitle.lblFeedback.text = "Setting the transparency level to 3..."
			viewport.SetTransparencyLevel 3
		)
		catch()

		rltTitle.lblFeedback.text = "Hiding the trackbar..."
		trackBar.visible = false

		rltTitle.lblFeedback.text = "Hiding the timeslider..."
		timeSlider.setVisible false

		rltTitle.lblFeedback.text = "Hiding the status panel..."
		statusPanel.visible = false

		-- Setting cui.expertModeOn(), either by script or via the UI increases the window's Y size by 25 each time the method is called.
		-- Turning off expert mode or using cui.expertModeOff() does not shrink the window by 25.
		rltTitle.lblFeedback.text = "Going to expert mode..."
		cui.expertModeOn()

		rltTitle.lblFeedback.text = "Removing menu..."
		if sCurrentMenu == "" then
		(
			sCurrentMenu = "MaxStartUI.mnu"
			menuMan.saveMenuFile sCurrentMenu
		)
		menuMan.loadMenuFile "MaxJack.mnu"


		-- Initialize materials
		rltTitle.lblFeedback.text = "Initializing materials..."
		for i = 1 to 24 do
		(
			rltTitle.lblFeedback.text = ("Setting material " + (i as string) + "to Standard...")
			meditmaterials[i] = standard() --Set the materials to standard type in case they are multimats
		)

		CardsMapArray = #()
		ChipsMapArray = #()

		--Populate materials 1-4 with the multimats for each card
		rltTitle.lblFeedback.text = "Creating card materials..."
		for i = 1 to 4 do
		(
			rltTitle.lblFeedback.text = ("Adding 13 submaterials to material " + (i as string) + "...")
			meditmaterials[i] = multimaterial numsubs:13
			case i of
			(
				1:	meditmaterials[i].name = "Spades"
				2:	meditmaterials[i].name = "Clubs"
				3:	meditmaterials[i].name = "Hearts"
				4:	meditmaterials[i].name = "Diamonds"
			)

			for j = 1 to meditmaterials[i].numsubs do
			(
				case i of
				(
					1:	(
							rltTitle.lblFeedback.text = "Creating Spades material..."
							append CardsMapArray (BitmapTexture filename:(sDataDir + "CardsSpades.jpg"))
							meditmaterials[i][j].diffusemap = CardsMapArray[CardsMapArray.count]
						)
					2:	(
							rltTitle.lblFeedback.text = "Creating Clubs material..."
							append CardsMapArray (BitmapTexture filename:(sDataDir + "CardsClubs.jpg"))
							meditmaterials[i][j].diffusemap = CardsMapArray[CardsMapArray.count]
						)
					3:	(
							rltTitle.lblFeedback.text = "Creating Hearts material..."
							append CardsMapArray (BitmapTexture filename:(sDataDir + "CardsHearts.jpg"))
							meditmaterials[i][j].diffusemap = CardsMapArray[CardsMapArray.count]
						)
					4:	(
							rltTitle.lblFeedback.text = "Creating Diamonds material..."
							append CardsMapArray (BitmapTexture filename:(sDataDir + "CardsDiamonds.jpg"))
		  					meditmaterials[i][j].diffusemap = CardsMapArray[CardsMapArray.count]
						)
				)

				rltTitle.lblFeedback.text = "Setting material and map parameters..."
				meditmaterials[i][j].glossiness = 50
				meditmaterials[i][j].specularlevel = 30

				try
				(
					meditmaterials[i][j].DirectX_Manager.dxStdMat = on
				)
				catch()

				meditmaterials[i][j].diffusemap.clipw = 0.0769231
				meditmaterials[i][j].diffusemap.clipu = ((j-1) * 0.0769231)
				meditmaterials[i][j].diffusemap.apply = true
				ShowTextureMap meditmaterials[i][j] meditmaterials[i][j].diffusemap on
			)
		)

		--Set material 5 to be the card back
		rltTitle.lblFeedback.text = "Creating card back material..."
		CardBackMat = getMeditMaterial 5
		CardBackMat.name = "Card Back"
		CardBackMat.diffusecolor = color 255 255 255
		CardBackMap = BitmapTexture filename:(sDataDir + "CardBack.jpg")
		CardBackMat.diffusemap = CardBackMap
		ShowTextureMap CardBackMat CardBackMat.diffusemap on

		--Set material 6 to be the chip images
		rltTitle.lblFeedback.text = "Creating chip materials..."
		meditmaterials[6] = multimaterial numsubs:6
		meditmaterials[6].name = "Chips"
		for i = 1 to 6 do
		(
			case i of
			(
				1:	(
						rltTitle.lblFeedback.text = "Creating the $5 chip material..."
						append ChipsMapArray (BitmapTexture filename:(sDataDir + "5.jpg"))
						meditmaterials[6][i].diffusemap = ChipsMapArray[i]
						meditmaterials[6][i].name = "$5"
					)

				2:	(
						rltTitle.lblFeedback.text = "Creating the $10 chip material..."
						append ChipsMapArray (BitmapTexture filename:(sDataDir + "10.jpg"))
						meditmaterials[6][i].diffusemap = ChipsMapArray[i]
						meditmaterials[6][i].name = "$10"
					)

				3:	(
						rltTitle.lblFeedback.text = "Creating the $50 chip material..."
						append ChipsMapArray (BitmapTexture filename:(sDataDir + "50.jpg"))
						meditmaterials[6][i].diffusemap = ChipsMapArray[i]
						meditmaterials[6][i].name = "$50"
					)

				4:	(
						rltTitle.lblFeedback.text = "Creating the $100 chip material..."
						append ChipsMapArray (BitmapTexture filename:(sDataDir + "100.jpg"))
						meditmaterials[6][i].diffusemap = ChipsMapArray[i]
						meditmaterials[6][i].name = "$100"
					)

				5:	(
						rltTitle.lblFeedback.text = "Creating the $500 chip material..."
						append ChipsMapArray (BitmapTexture filename:(sDataDir + "500.jpg"))
						meditmaterials[6][i].diffusemap = ChipsMapArray[i]
						meditmaterials[6][i].name = "$500"
					)

				6:	(
						rltTitle.lblFeedback.text = "Creating the $1000 chip material..."
						append ChipsMapArray (BitmapTexture filename:(sDataDir + "1000.jpg"))
						meditmaterials[6][i].diffusemap = ChipsMapArray[i]
						meditmaterials[6][i].name = "$1000"
					)
			)

			rltTitle.lblFeedback.text = "Setting material and map parameters..."
			meditmaterials[6][i].glossiness = 30
			meditmaterials[6][i].specularlevel = 80

			try
			(
				meditmaterials[6][i].DirectX_Manager.dxStdMat = on
			)
			catch()

			ShowTextureMap meditmaterials[6][i] meditmaterials[6][i].diffusemap on
		)

		-- Merge table, display its materials, and set viewport to the camera
		rltTitle.lblFeedback.text = "Adding the table..."
		mergeMaxFile (sDataDir + "Table.max") quiet:true

		$_Table.material[1].diffusemap.filename = (sDataDir + "Table.jpg")
		viewport.setCamera $Camera01
		redrawViews()

		--Show the controls.
		rltTitle.lblFeedback.text = "Building the UI..."
		if rltMaxJack != undefined then
		(
			destroyDialog rltMaxJack
		)

		--p2WindowSize = getMaxWindowSize()
		p2WindowSize = [gw.getWinSizeX(), gw.getWinSizeY()]

		-- In a try/catch to restore Max on any general failures
		createDialog rltMaxJack 464 170 (p2WindowSize.x - 500) (p2WindowSize.y - 200) style:#(#style_border) bitmap:bmpControlBackground fgcolor:white

		--Get the stored bankroll for the player. If the value doesn't exist or is 0 then give the player $10000.00
		rltTitle.lblFeedback.text = "Initializing player 1..."
		Player1.Cash = ((GetINISetting "$plugcfg/MaxJack.ini" "Winnings" "Cash") as integer)

		if Player1.Cash == 0 then
		(
			Player1.Cash = 25000
		)

		ClearTable()
		
		-- Fill the shoe with the proper number of decks of cards.
		for i = 1 to iNumberOfDecks do	join CardShoe CardDeckArray

		-- Initial shuffle, cut, and burn
		rltTitle.lblFeedback.text = "Shuffling..."
		CardShoe = Shuffle CardShoe

	 	destroyDialog rltTitle

	 	clearSelection()
		
		rltMaxJack.lblCash.text = ("$" + Player1.Cash as string)

	 	-- At this point code execution will be in the rollout's "on <event> do" code blocks
	)
	catch
	(
		RestoreMaxAndQuit()
	)
)