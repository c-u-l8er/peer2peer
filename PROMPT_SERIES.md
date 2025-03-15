

# Prompts Series for P2P Idea Chat System Development

Here's a series of prompts to help you build your P2P Idea Chat System in Elixir/Phoenix, organized in a logical development sequence:

## Phase 1: Project Setup and Core Architecture

### Prompt 1: Project Initialization
```
Create a new Phoenix project for the P2P Idea Chat System with the following specifications:
- Phoenix 1.7+ with LiveView
- PostgreSQL database
- Authentication system using Phx.Gen.Auth
- Basic project structure with proper naming conventions
- Include recommended dependencies for real-time features
Provide the mix commands and initial configuration steps.
```

### Prompt 2: Database Schema Design
```
Design the database schemas for the P2P Idea Chat System, including:
1. User schema (with authentication)
2. Conversation schema (supporting the mitosis concept)
3. Message schema (supporting both human and AI messages)
4. ConversationRelationship schema (for tracking parent/child relationships)
5. AIParticipant schema (for configuring AI in conversations)

Include all necessary fields, associations, and migrations.
```

### Prompt 3: Phoenix LiveView Chat Foundation
```
Implement the core LiveView chat functionality for the P2P Idea Chat System:
1. LiveView structure for real-time chat
2. PubSub configuration for message broadcasting
3. Presence tracking for active users
4. Basic message sending/receiving functionality
5. Real-time updates with optimistic UI

Provide the necessary module code, templates, and LiveView hooks.
```

## Phase 2: AI Integration and Context Management

### Prompt 4: AI Service Integration
```
Create an Elixir module to integrate external AI services with the chat system:
1. Configuration for multiple AI providers (OpenAI, Anthropic, etc.)
2. Adaptive client for sending requests to chosen providers
3. Response handling with support for streaming
4. Error handling and fallback mechanisms
5. Rate limiting and request queueing

Include complete module code with examples of how to use it from LiveView.
```

### Prompt 5: Conversation Context Management
```
Develop a context management system for AI participants in conversations:
1. Efficient storage of conversation history
2. Context window management to handle long conversations
3. Support for AI memory across conversation splits
4. Personality/persona system for AI participants
5. Context pruning strategies for performance

Provide the implementation with consideration for scalability.
```

## Phase 3: Mitosis Implementation and Visualization

### Prompt 6: Conversation State Machine
```
Implement a state machine to manage the mitosis phases of conversations:
1. GenServer implementation for tracking conversation state
2. Logic for phase transitions (Prophase → Prometaphase → Metaphase → Anaphase → Telophase)
3. Events and triggers that cause phase changes
4. Broadcast mechanisms for phase updates
5. Persistence of phase information

Include the complete GenServer implementation with phase transition logic.
```

### Prompt 7: Visualization Framework
```
Create the visualization system for displaying conversation evolution:
1. LiveView hooks for connecting Elixir state to JavaScript
2. Canvas/SVG setup for physics-based visualization
3. Force-directed layout for topic relationships
4. Visual representations for each mitosis phase
5. Interactive elements for user engagement

Provide JavaScript and LiveView code for the visualization system.
```

## Phase 4: Conversation Division and Navigation

### Prompt 8: Conversation Division Mechanics
```
Implement the mechanics for splitting conversations through mitosis:
1. Algorithms for identifying divergent topics
2. User interface for suggesting/approving splits
3. Backend logic for creating new conversation spaces
4. Data migration during splits
5. Maintaining relationship links between parent/child conversations

Include both frontend and backend code for this functionality.
```

### Prompt 9: Inter-Conversation Navigation
```
Develop the navigation system for related conversations:
1. UI components for displaying conversation relationships
2. Transition animations between conversation spaces
3. History tracking across related conversations
4. Breadcrumb-style navigation for conversation lineage
5. Quick-switch functionality between active conversations

Provide the code for navigation components and state management.
```

## Phase 5: UI Polish and Deployment Preparation

### Prompt 10: User Interface Refinement
```
Design the polished user interface for the chat system:
1. Message bubbles with clear human/AI distinction
2. Typing indicators with different animations
3. Phase indicator with explanatory tooltips
4. Topic map mini-visualization
5. Mobile-responsive layout adjustments

Include HTML/CSS templates and LiveView rendering code.
```

### Prompt 11: Deployment Configuration
```
Create a deployment configuration for the P2P Idea Chat System:
1. Production environment setup
2. Distributed Elixir configuration for scalability
3. AI service fallback strategies
4. Monitoring and logging setup
5. Database optimization for production

Provide configuration files and deployment instructions.
```

## Bonus Prompts

### Prompt 12: Performance Optimization
```
Optimize the performance of the P2P Idea Chat System:
1. Message delivery optimization techniques
2. Database query improvements
3. LiveView render optimization
4. Visualization performance tuning
5. AI request caching strategies

Include code changes and configuration adjustments to improve performance.
```

### Prompt 13: Testing Strategy
```
Develop a comprehensive testing strategy for the system:
1. Unit tests for critical components
2. Integration tests for conversation flows
3. LiveView testing approach
4. AI service mocking
5. Performance benchmarking tests

Provide example test cases and testing configuration.
