# Prompt for P2P Idea Chat System in Elixir/Phoenix

## Overview

Create an Elixir/Phoenix application that implements a peer-to-peer idea chat system as described in the website. This system should allow users to chat with each other or with AI in the same conversation space, with ideas evolving, propagating, and subdividing through a process that mimics cellular mitosis. The system should facilitate natural collaborative intelligence by allowing conversations to grow and divide organically.

## Core Architectural Requirements

1. **Phoenix LiveView Chat System**
   - Use Phoenix LiveView for real-time chat interface
   - Implement Phoenix PubSub for message broadcasting
   - Use Phoenix Presence to track active users in conversation spaces

2. **Shared Conversation Box Architecture**
   - Create a unified conversation interface where humans and AI can interact equally
   - Enable seamless switching between human-to-human and human-to-AI interactions
   - Implement typing indicators that distinguish between human and AI participants

3. **AI Integration**
   - Create an Elixir module to connect with external AI services (like OpenAI, Anthropic, etc.)
   - Implement conversation memory and context management for AI participants
   - Design AI personas that can participate naturally in conversations

4. **Mitosis-Based Conversation Evolution**
   - Model each chat space as a "cell" that can grow and divide
   - Implement the 5-phase mitosis model for conversation evolution:
     * Prophase: Initial ideas are organized and structured
     * Prometaphase: Barriers between topics/users break down
     * Metaphase: Ideas align and reach consensus
     * Anaphase: Conversation begins splitting into separate threads
     * Telophase: Complete separation into new conversation groups

## Database and Storage

1. **PostgreSQL with Ecto**
   - Design schemas for users, messages, and conversations
   - Implement conversation threading and history retention
   - Track conversation "mitosis" events and relationships

2. **Schemas**
   - `User`: Authentication and profile information
   - `Message`: Individual chat messages with metadata
   - `Conversation`: Chat spaces that can evolve and divide
   - `ConversationRelationship`: Track parent/child relationships between conversations
   - `AIParticipant`: Configuration for AI participants in conversations

## UI/UX Requirements

1. **Interactive Chat Interface**
   - Create a modern, responsive chat interface using LiveView
   - Implement dynamic scrolling with history loading
   - Show visual cues for AI vs. human messages

2. **Conversation Visualization**
   - Display the current "mitosis phase" of the conversation with visual indicators
   - Use a physics-based visualization (similar to Matter.js as shown on the site) to illustrate how ideas are connecting
   - Include a mini-map of conversation topics and their relationships

3. **Phase Transitions**
   - Design smooth visual transitions as conversations move through mitosis phases
   - Show metaphase alignment when ideas reach consensus
   - Animate separation when conversations divide

4. **User Experience**
   - Allow users to initiate conversation splits when topics diverge
   - Provide a way to navigate between related conversation spaces
   - Include tooltips explaining the mitosis metaphor

## Feature Requirements

1. **Conversation Initiation (Prophase)**
   - Users and AI can start new conversations
   - System organizes initial messages and detects main topics
   - Users can invite others to join the conversation space

2. **Topic Expansion (Prometaphase)**
   - Ideas flow freely between participants
   - AI suggests connections between seemingly unrelated points
   - System visualizes emerging topic clusters

3. **Idea Consensus (Metaphase)**
   - System highlights areas of agreement between participants
   - AI offers synthesis of viewpoints when appropriate
   - Interface visually aligns related ideas at the "metaphase plate"

4. **Topic Divergence (Anaphase)**
   - Interface suggests potential conversation splits when topics diverge
   - Users can vote or approve conversation division
   - System prepares to create separate but linked conversation spaces

5. **Conversation Division (Telophase & Cytokinesis)**
   - Conversation divides into two related spaces
   - System maintains links between parent and child conversations
   - Users can seamlessly move between related conversation spaces

## Technical Implementation Details

1. **LiveView Chat Implementation**
   - Use LiveView to manage real-time message delivery
   - Implement optimistic UI updates for better user experience
   - Create custom message rendering for different message types

2. **AI Message Processing**
   - Implement message queuing for AI responses
   - Create streaming responses for more natural AI interactions
   - Design fallback mechanisms for when AI services are unavailable

3. **Conversation State Management**
   - Track conversation phase in an Elixir GenServer
   - Implement state machine for phase transitions
   - Create phase-specific behavior rules

4. **Visualization Engine**
   - Use Canvas/SVG with JavaScript for physics-based visualizations
   - Create LiveView hooks to connect Elixir state with JS visualizations
   - Implement force-directed layouts for conversation topics

## Specific UI Components

1. **Chat Interface**
   - Message bubbles with avatars for human users
   - Distinct styling for AI messages
   - Typing indicators with different animations for humans vs. AI
   - Inline controls for managing conversation flow

2. **Mitosis Phase Indicator**
   - Visual progress bar showing current phase
   - Interactive tooltips explaining each phase
   - Subtle animations during phase transitions

3. **Topic Map**
   - Small visualization showing conversation topics as nodes
   - Lines connecting related topics
   - Visual indication of conversation division points

4. **User Controls**
   - Buttons to trigger/approve conversation division
   - Tools to highlight and connect ideas
   - Navigation controls for moving between related conversations

## Project Implementation Phases

1. **Phase 1: Core Chat Functionality**
   - Build basic LiveView chat system
   - Implement user authentication
   - Create conversation persistence

2. **Phase 2: AI Integration**
   - Add AI participants to conversations
   - Implement context management for AI
   - Create natural conversation flow between humans and AI

3. **Phase 3: Mitosis Visualization**
   - Build the physics-based visualization engine
   - Implement all 5 phase visualizations
   - Create the logic for phase transitions

4. **Phase 4: Conversation Division**
   - Implement the mechanics of conversation splitting
   - Create navigation between related conversations
   - Build history and relationship tracking

## Deployment Considerations

1. **Scalability**
   - Design for multiple conversation spaces running simultaneously
   - Implement efficient PubSub usage for message broadcasting
   - Consider using distributed Elixir for larger deployments

2. **AI Service Management**
   - Implement rate limiting and queueing for AI services
   - Create fallback responses for service outages
   - Consider local embeddings for some basic AI functionality

3. **User Experience**
   - Ensure responsive design for mobile users
   - Implement graceful degradation for older browsers
   - Consider accessibility throughout the design process

Create this system with a focus on natural conversation flow, beautiful visualizations of the mitosis process, and seamless integration of human and AI participants in the same conversation spaces.
