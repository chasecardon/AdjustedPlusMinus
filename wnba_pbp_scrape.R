## David Teuscher
## Latest changes: 19.05.2021
## This script reads in play by play data for WNBA games and determines that 
## players on the court at the time
########################################################

# Install the wehoop package
# devtools::install_github(repo = "saiemgilani/wehoop")
library(wehoop)
library(tidyverse)

# Read in the play by play data for the Dallas Wings vs. Atlanta Dream on May 24, 2019
pbp <- espn_wnba_pbp(game_id = "401104913")

# Bring in the box score data and filter for only the starters to get the lineup at the 
# beginning of the game
box_score <- wehoop::espn_wnba_player_box(game_id = "401104913") %>%
  filter(starter == TRUE)

# Create empty vectors for the lineups for both teams
# Length is the same length as the play by play 
LineupAway <- character(nrow(pbp))
LineupHome <- character(nrow(pbp))

# Set the starting lineup for both teams; 
# Away team is always the first 5 players
# Home team is the second 5 players
LineupAway[1] <- paste(box_score$athlete_display_name[1:5], collapse = ",")
LineupHome[1] <- paste(box_score$athlete_display_name[6:10], collapse = ",")

# Loop through every row on the play by play data 
for(i in 2:nrow(pbp)){
  # If the play is a substitution, change the lineup
  if(pbp$type_text[i] == "Substitution"){
    # Determine the player coming in and the player coming out of the game
    player_in <- str_extract(pbp$text[i], "^^[A-Z][-a-zA-Z]+ [A-Z][-a-zA-Z]+")
    player_out <- str_extract(pbp$text[i], "[A-Z][-a-zA-Z]+ [A-Z][-a-zA-Z]+$")
    
    # If the player going out is on the away team, substitute the player in on the 
    # away team. If they aren't on the away team, then sub them for the home team
    if(str_detect(LineupAway[i -1], player_out)){
      LineupAway[i] <- str_replace(LineupAway[i-1], player_out, player_in)
      LineupHome[i] <- LineupHome[i-1]
    } else{
      LineupHome[i] <- str_replace(LineupHome[i-1], player_out, player_in)
      LineupAway[i] <- LineupAway[i-1]
    }
  }
  
  # If it isn't a substitution, keep the lineup the same as the previous play
  else{
    LineupAway[i] <- LineupAway[i-1]
    LineupHome[i] <- LineupHome[i-1]
  }
}

# Combine the lineup with the play by play data
test <- pbp %>% bind_cols(LineupAway = LineupAway, LineupHome = LineupHome)
points <- sample(c(2, 3, 0), nrow(test), replace = TRUE)
test2 <- test %>% 
  mutate(point_diff = points) %>% 
  separate(LineupAway, into = c("P1", "P2", "P3", "P4", "P5"), sep = ",") %>%
  separate(LineupHome, into = c("P6", "P7", "P8", "P9", "P10"), sep = ",") %>% 
  pivot_longer(cols = P1:P10, values_to = "Player", names_to =  NULL) %>%
  mutate(Player = factor(Player))

X <- model.matrix(point_diff ~ -1 + Player, data = test2)

ids <- seq(10, 4530, by = 10)
X_small <- matrix(0, nrow = nrow(X)/10, ncol = ncol(X))
colnames(X_small) <- colnames(X)
for(i in ids){
  k <- i/10
  for(j in 1:ncol(X)){
    X_small[k, j] <- sum(X[(i-9):i, j]) 
  }
}

# Select variables that are needed to pull out possession information
possession <- test %>% select(shooting_play, home_score, scoring_play, away_score,
                             text, score_value, team_id, type_text, LineupAway,
                             LineupHome, clock_display_value)

turnover_types <- c("Out of Bounds - Lost Ball Turnover", "Offensive Foul Turnover", "Shot Clock Turnover", "Bad Pass\nTurnover",
                    "Lost Ball Turnover", "Out of Bounds - Bad Pass Turnover", "Traveling")

change_possession <- numeric(nrow(possession))
cond <- (possession$shooting_play == TRUE & possession$scoring_play == TRUE) | 
  possession$type_text == "Defensive Rebound" | possession$type_text %in% turnover_types
for(i in 2:nrow(possession)){
  if(cond[i] == TRUE){
    change_possession[i] <- 1
  }
  if(possession$type_text[i] == "Shooting Foul" & (possession$clock_display_value[i] == possession$clock_display_value[i-1])){
    change_possession[i-1] <- 0
  }
}

possession <- possession %>% mutate(change_possession = change_possession)
View(possession %>% select(scoring_play, shooting_play, type_text, text, change_possession, clock_display_value))
