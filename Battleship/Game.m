//
//  Game.m
//  Battleship
//
//  Created by Ahmet Geymen on 4/30/13.
//  Copyright (c) 2013 Ahmet Geymen. All rights reserved.
//

#import "Game.h"

#import "Packet.h"
#import "Player.h"


typedef enum
{
	GameStateWaitingForSignIn,
	GameStateWaitingForReady,
	GameStateDealing,
	GameStatePlaying,
	GameStateGameOver,
	GameStateQuitting,
}
GameState;


@implementation Game
{
    GameState _state;
    
	GKSession *_session;
	NSString *_serverPeerID;
	NSString *_localPlayerName;
    
    NSMutableDictionary *_players;
}

- (id)init
{
    if (self = [super init]) {
        _players = [NSMutableDictionary dictionaryWithCapacity:2];
    }
    return self;
}


#pragma mark - *** Game Logic ***

- (void)startClientGameWithSession:(GKSession *)session playerName:(NSString *)name server:(NSString *)peerID
{
    self.isServer = NO;
    
	_session = session;
	_session.available = NO;
	_session.delegate = self;
	[_session setDataReceiveHandler:self withContext:nil];
    
	_serverPeerID = peerID;
	_localPlayerName = name;
    
	_state = GameStateWaitingForSignIn;
    
	[self.delegate gameWaitingForServerReady:self];
}

- (void)startServerGameWithSession:(GKSession *)session playerName:(NSString *)name clients:(NSArray *)clients
{
    self.isServer = YES;
    
	_session = session;
	_session.available = NO;
	_session.delegate = self;
	[_session setDataReceiveHandler:self withContext:nil];
    
	_state = GameStateWaitingForSignIn;
    
	[self.delegate gameWaitingForClientsReady:self];
    
	// Create the Player object for the server.
	Player *player = [[Player alloc] init];
	player.name = name;
	player.peerID = _session.peerID;
	player.type = PlayerLocal;
	[_players setObject:player forKey:player.peerID];
    
	// Add a Player object for each client.
//	int index = 0;
	for (NSString *peerID in clients)
	{
		Player *player = [[Player alloc] init];
		player.peerID = peerID;
        player.type = PlayerOpponent;
		[_players setObject:player forKey:player.peerID];
        
//		if (index == 0)
//			player.position = ([clients count] == 1) ? PlayerPositionTop : PlayerPositionLeft;
//		else if (index == 1)
//			player.position = PlayerPositionTop;
//		else
//			player.position = PlayerPositionRight;
//        
//		index++;

	}
    
	Packet *packet = [Packet packetWithType:PacketTypeSignInRequest];
	[self sendPacketToAllClients:packet];
}

- (void)quitGameWithReason:(QuitReason)reason
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
    
	_state = GameStateQuitting;
    
	if (reason == QuitReasonUserQuit)
	{
		if (self.isServer)
		{
//			Packet *packet = [Packet packetWithType:PacketTypeServerQuit];
//			[self sendPacketToAllClients:packet];
		}
		else
		{
//			Packet *packet = [Packet packetWithType:PacketTypeClientQuit];
//			[self sendPacketToServer:packet];
		}
	}
    
	[_session disconnectFromAllPeers];
	_session.delegate = nil;
	_session = nil;
    
	[self.delegate game:self didQuitWithReason:reason];
}


#pragma mark - Networking

- (void)sendPacketToAllClients:(Packet *)packet
{
//	if ([self isSinglePlayerGame])
//		return;
    
	// If packet numbering is enabled, each packet that we send out gets a
	// unique number that keeps increasing. This is used to ignore packets
	// that arrive out-of-order.
//	if (packet.packetNumber != -1)
//		packet.packetNumber = _sendPacketNumber++;
    
//	[_players enumerateKeysAndObjectsUsingBlock:^(id key, Player *obj, BOOL *stop)
//     {
//         obj.receivedResponse = [_session.peerID isEqualToString:obj.peerID];
//     }];
    
	GKSendDataMode dataMode = packet.sendReliably ? GKSendDataReliable : GKSendDataUnreliable;
    
	NSData *data = [packet data];
	NSError *error;
	if (![_session sendDataToAllPeers:data withDataMode:dataMode error:&error])
	{
		NSLog(@"Error sending data to clients: %@", error);
	}
}

- (void)sendPacketToServer:(Packet *)packet
{
//	NSAssert(![self isSinglePlayerGame], @"Should not send packets in single player mode");
    
//	if (packet.packetNumber != -1)
//		packet.packetNumber = _sendPacketNumber++;
    
	GKSendDataMode dataMode = packet.sendReliably ? GKSendDataReliable : GKSendDataUnreliable;
    
	NSData *data = [packet data];
	NSError *error;
	if (![_session sendData:data toPeers:[NSArray arrayWithObject:_serverPeerID] withDataMode:dataMode error:&error])
	{
		NSLog(@"Error sending data to server: %@", error);
	}
}

- (Player *)playerWithPeerID:(NSString *)peerID
{
	return [_players objectForKey:peerID];
}

#pragma mark - *** GKSessionDelegate ***

- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state
{
    #ifdef DEBUG
	NSLog(@"Game: peer %@ changed state %d", peerID, state);
    #endif
	
	if (state == GKPeerStateDisconnected)
	{
		if (self.isServer)
		{
//			[self clientDidDisconnect:peerID redistributedCards:nil];
		}
		else if ([peerID isEqualToString:_serverPeerID])
		{
			[self quitGameWithReason:QuitReasonConnectionDropped];
		}
	}
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID
{
    #ifdef DEBUG
	NSLog(@"Game: connection request from peer %@", peerID);
    #endif
    
	[session denyConnectionFromPeer:peerID];
}

- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error
{
    #ifdef DEBUG
	NSLog(@"Game: connection with peer %@ failed %@", peerID, error);
    #endif
    
	// Not used.
}

- (void)session:(GKSession *)session didFailWithError:(NSError *)error
{
    #ifdef DEBUG
	NSLog(@"Game: session failed %@", error);
    #endif
    
	if ([[error domain] isEqualToString:GKSessionErrorDomain])
	{
		if (_state != GameStateQuitting)
		{
			[self quitGameWithReason:QuitReasonConnectionDropped];
		}
	}
}


#pragma mark - *** GKSession Data Receive Handler ***

- (void)receiveData:(NSData *)data fromPeer:(NSString *)peerID inSession:(GKSession *)session context:(void *)context
{
#ifdef DEBUG
	NSLog(@"Game: receive data from peer: %@, data: %@, length: %d", peerID, data, [data length]);
#endif
    
	Packet *packet = [Packet packetWithData:data];
	if (packet == nil)
	{
		NSLog(@"Invalid packet: %@", data);
		return;
	}
    
	Player *player = [self playerWithPeerID:peerID];
//	if (player != nil)
//	{
//		if (packet.packetNumber != -1 && packet.packetNumber <= player.lastPacketNumberReceived)
//		{
//			NSLog(@"Out-of-order packet!");
//			return;
//		}
//        
//		player.lastPacketNumberReceived = packet.packetNumber;
//		player.receivedResponse = YES;
//	}
    
	if (self.isServer)
		[self serverReceivedPacket:packet fromPlayer:player];
	else
		[self clientReceivedPacket:packet];
}

- (void)serverReceivedPacket:(Packet *)packet fromPlayer:(Player *)player
{
    
}

- (void)clientReceivedPacket:(Packet *)packet
{
    switch (packet.packetType)
    {
        case PacketTypeSignInRequest:
            if (_state == GameStateWaitingForSignIn)
			{
				_state = GameStateWaitingForReady;
                
//				Packet *packet = [PacketSignInResponse packetWithPlayerName:_localPlayerName];
				[self sendPacketToServer:packet];
			}
            break;
            
        default:
            NSLog(@"Client received unexpected packet: %@", packet);
            break;
    }
}

@end
