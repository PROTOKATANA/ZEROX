 Cordial Miners: Fast and Efficient Consensus for Every Eventuality          

##### Report GitHub Issue

×

Title: 

Content selection saved. Describe the issue below:

Description:

Submit without GitHub Submit in GitHub

![](/static/base/1.0.1/images/icons/smileybones-small.svg) arXiv is now an independent nonprofit! [Learn more](https://info.arxiv.org/about) ×

 [![arXiv logo](/static/base/1.0.1/images/arxiv-logo-primary-light.svg) Back to arXiv](/)

[Why HTML?](https://info.arxiv.org/about/accessible_HTML.html) [Report Issue](# "Report an Issue") [Back to Abstract](/abs/2205.09174v6 "Back to abstract page") [Download PDF](/pdf/2205.09174v6 "Download PDF")[](javascript:toggleNavTOC\(\); "Toggle navigation")[](javascript:toggleReadingMode\(\); "Disable reading mode, show header and footer")

1.  [Acknowledgements](#acknowledgements1 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
2.  [Abstract](#abstract1 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
3.  [1 Introduction](#S1 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
4.  [2 Model and Problem Definition](#S2 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
5.  [3 Cordial Miners Overview](#S3 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
6.  [4 The Blocklace](#S4 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
    1.  [4.1 Blocklace Basics](#S4.SS1 "In 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
    2.  [4.2 Blocklace Safety](#S4.SS2 "In 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
    3.  [4.3 Blocklace Liveness](#S4.SS3 "In 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
7.  [5 Blocklace Ordering with τ\\tau](#S5 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
8.  [6 The Cordial Miners Protocols](#S6 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
    1.  [6.1 Dissemination (Alg. )](#S6.SS1 "In 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
    2.  [6.2 Specific utilities (Alg. )](#S6.SS2 "In 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
    3.  [6.3 Correctness Proof Outline](#S6.SS3 "In 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
9.  [7 Performance Analysis](#S7 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
10.  [8 Related Work](#S8 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
11.  [9 Conclusion](#S9 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
12.  [References](#bib "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
13.  [A Formal Model](#A1 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
14.  [B Figures](#A2 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
15.  [C Proofs](#A3 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")
16.  [D Future Direction and Optimizations](#A4 "In Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

[License: CC BY-NC-ND 4.0](https://info.arxiv.org/help/license/index.html#licenses-available)

arXiv:2205.09174v6 \[cs.DC\] 22 Sep 2023

Technion Technion and StarkWare Ben-Gurion University Weizmann Institute of Science {CCSXML}¡ccs2012¿ ¡concept¿ ¡concept\_id¿10010147.10010919.10010172¡/concept\_id¿ ¡concept\_desc¿Computing methodologies Distributed algorithms¡/concept\_desc¿ ¡concept\_significance¿500¡/concept\_significance¿ ¡/concept¿ ¡/ccs2012¿

Oded Naor is grateful to the Azrieli Foundation for the award of an Azrieli Fellowship, and to the Technion Hiroshi Fujiwara Cyber-Security Research Center for providing a research grant. Ehud Shapiro is the Incumbent of The Harry Weinrebe Professorial Chair of Computer Science and Biology at the Weizmann Institute.

# Cordial Miners: Fast and Efficient Consensus for Every Eventuality

Idit Keidar    Oded Naor    Ouri Poupko    Ehud Shapiro

###### Abstract

Cordial Miners are a family of efficient Byzantine Atomic Broadcast protocols, with instances for asynchrony and eventual synchrony. They improve the latency of state-of-the-art DAG-based protocols by almost 2×2\\times and achieve optimal good-case complexity of O⁡(n)O(n) by forgoing Reliable Broadcast as a building block. Rather, Cordial Miners use the *blocklace*—a partially-ordered counterpart of the totally-ordered blockchain data structure—to implement the three algorithmic components of consensus: Dissemination, equivocation-exclusion, and ordering.

###### ccs

Computing methodologies Distributed algorithms

###### keywords

Byzantine Fault Tolerance, State Machine Replication, DAG, Consensus, Blockchain, Blocklace, Cordial Dissemination

††editors: Rotem Oshman††event-title: 37th International Symposium on Distributed Computing (DISC 2023)††event-shorttitle: DISC 2023††event-acronym: DISC††year: 2023††event-date: October 10-12, 2023††event-location: L’Aquila, Italy††series-volume: 281††articleno: 23††runningtitle: Cordial Miners ††runningauthor: Keidar, Naor, Poupko, and Shapiro††copyright: Idit keidar, Oded Naor, Ouri Poupko, and Ehud Shapiro ††relatedversion: Cordial Miners: Fast and Efficient Consensus for Every Eventuality††related-version: Full Version: [https://arxiv.org/abs/2205.09174](https://arxiv.org/abs/2205.09174)

## 1 Introduction

The problem of ordering transactions in a permissioned Byzantine distributed system, also known as *Byzantine Atomic Broadcast (BAB)*, has been investigated for four decades \[[30](#bib.bib30)\], and in the last decade, has attracted renewed attention due to the emergence of cryptocurrencies.

Recently, a line of works \[[4](#bib.bib4), [14](#bib.bib14), [20](#bib.bib20), [33](#bib.bib33), [21](#bib.bib21), [27](#bib.bib27)\] suggests ordering transactions using a distributed Directed Acyclic Graph (DAG) structure, in which each vertex contains a block of transactions as well as references to previously sent vertices. The DAG is distributively constructed from messages of *miners* running the consensus protocol. While building the DAG structure, each miner also totally orders the vertices in its DAG locally. That is, as the DAG is being constructed, a consensus on its ordering emerges without additional communication among the miners.

The two state-of-the-art protocols in this context are DAG-Rider \[[21](#bib.bib21)\] and Bullshark \[[33](#bib.bib33)\]. DAG-Rider works in the asynchronous setting, in which the adversary controls the finite delay on message delivery between miners, and Bullshark works in the Eventual Synchrony (ES) model, in which eventually all messages between correct miners are delivered within a known time-bound.

Both protocols use *Reliable Broadcast (RB)* \[[7](#bib.bib7)\] as a building block to disseminate vertices in the DAG. RB ensures that Byzantine miners cannot equivocate, i.e., they cannot successfully send two conflicting vertices to the correct miners. By using RB to exclude equivocation, the DAGs of all correct miners eventually contain the same vertices.

But using RB has costs in terms of message complexity and latency. The well-known Bracha RB \[[7](#bib.bib7)\] protocol entails O⁡(n2)O(n^{2}) message complexity for each broadcast message, where nn is the number of miners, and has a latency of 33 rounds of communication. The lower bound for RB is 2 rounds \[[2](#bib.bib2)\], and the message complexity lower bound is O⁡(n2)O(n^{2}) \[[19](#bib.bib19)\]. Recent RB protocols \[[15](#bib.bib15), [16](#bib.bib16)\] improve the message complexity to O⁡(n)O(n) in some cases by using erasure codes \[[5](#bib.bib5)\], but require between 4 to 5 rounds of communication.

DAG-Rider and Bullshark need to invoke a sequence of RB instances several times to reach a single instance of consensus. E.g., DAG-Rider requires 6 sequential instances of RB in the expected case, making its latency between 12 to 24 rounds of communication, depending on the RB protocol it uses. Bullshark requires between 9 to 18 rounds in the expected case in the ES model.

Protocol

Reliable Broadcast Used

Latency

Amortized Message Complexity

Eventual Synch.

Async.

Good

Expected

Good

Expected

Cordial Miners (this work)

None

33

4.5

55

7.57.5

good-case: O⁡(n)O(n)

worst-case: O⁡(n2)O(n^{2})

Bullshark (for ES)

Optimal latency \[[2](#bib.bib2)\]

4

99

8

12

good- & worst-case: O⁡(n2)O(n^{2})

DAG-Rider (for asynch.)

Das et al. \[[15](#bib.bib15)\]

8

1818

16

24

good- & worst-case: O⁡(n)O(n)

Table 1: Performance summary. Bullshark is for the ES model, and DAG-Rider is for the asynchronous model. Both protocols employ RB, which requires at least two rounds of communication of simple messages for optimal latency \[[2](#bib.bib2)\] and O⁡(n2)O(n^{2}) amortized message complexity, or four rounds with erasure coding when using Das et al. \[[15](#bib.bib15)\] and O⁡(n)O(n) amortized message complexity.

It is within this context that we introduce *Cordial Miners* – a family of simple, efficient, self-contained Byzantine Atomic Broadcast \[[9](#bib.bib9)\] protocols that forgo RB, and present two of its instances for the models ES and asynchrony.

The ES Cordial Miners protocol reduces the expected latency from 9 rounds in today’s state-of-the-art to 4.5, and the good case latency from 4 to 3. The asynchronous version of Cordial Miners improves the expected latency from 12 rounds to 7.5, and the good case latency from 8 to 5. This is while maintaining the same amortized quadratic message complexity in the worst case. Cordial Miners also demonstrates better performance with O⁡(n)O(n) complexity in the good case when the actual number of Byzantine miners is O⁡(1)O(1) and the network is synchronous. Protocols that use RB do not differ in their performance between the good and worst cases. Tab. [1](#S1.T1 "Table 1 ‣ 1 Introduction ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") summarizes Cordial Miners’ performance compared to DAG-Rider (for asynchrony) and Bullshark (for ES).

The crux of the Cordial Miners protocols is that instead of using RB to eliminate equivocation (and absorbing its rather high latency), miners cooperatively create a data structure that accommodates equivocations, termed *blocklace*, which is a partially-ordered counterpart of the blockchain data structure \[[29](#bib.bib29)\]. When a miner wishes to disseminate a block, it simply sends it to all other miners, taking a single round of communication, instead of at least two when using reliable broadcast.

Although the blocklace may contain equivocating blocks created by Byzantine miners, they are excluded by the ordering protocol, which is locally computed by each miner without inducing any extra communication or latency. This is realized by the function τ\\tau that converts the partially-ordered blocklace to a totally-ordered sequence of blocks while excluding equivocations along the way. Thus, by ‘complicating’ the local ordering task to exclude equivocations, we forgo the extra communication rounds and latency associated with RB.

Roadmap. The rest of the paper is structured as follows: [Section 2](#S2 "2 Model and Problem Definition ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") describes the models and defines the problem; [Section 3](#S3 "3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") provides intuition and overview of the different components; [Section 4](#S4 "4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") introduces the blocklace data structure; [Section 5](#S5 "5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") explains the τ\\tau function that locally turns the blocklace into a totally-ordered sequence of blocks; [Section 6](#S6 "6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") describes the entire Cordial Miners protocols for the two network models; [Section 7](#S7 "7 Performance Analysis ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") presents the performance analysis; [Section 8](#S8 "8 Related Work ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") is related work; and lastly, [Section 9](#S9 "9 Conclusion ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") concludes the paper. To accommodate the space limitations some details are deferred to the appendices. App. [A](#A1 "Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") describes a formal mathematical model for cordial miners, and some explanatory figures are deferred to App. [B](#A2 "Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). Most of the proofs are deferred to App. [C](#A3 "Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). Potential future directions are in App. [D](#A4 "Appendix D Future Direction and Optimizations ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). Appendices [C](#A3 "Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). and [D](#A4 "Appendix D Future Direction and Optimizations ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). appear in the full version of this paper \[[22](#bib.bib22)\].

## 2 Model and Problem Definition

We assume a set Π\\Pi of n≥3n\\geq 3 *miners* (aka agents, processes), of which at most f<n/3f<n/3 may be *faulty* (act under the control of the adversary, be ‘Byzantine’), and the rest are *correct* (also honest or non-faulty). Each miner is equipped with a single and unique cryptographic key-pair, with the public key known to others. Miners can create, sign, and send messages to each other, where any message sent from one correct miner to another is eventually received. In addition, each miner can sequentially *output* (aka ‘deliver’) messages (e.g., to a local output device or storage device). Thus, each miner outputs a *sequence* of messages.

Let Λ\\Lambda denote the empty sequence; for a set XX, X∗X^{\*} is the set of all sequences over XX; for sequences xx and yy, x⪯yx\\preceq y denotes that xx is a prefix of yy; x⋅yx\\cdot y denotes the concatenation of xx and yy; and x,yx,y are *consistent* if x⪯yx\\preceq y or y⪯xy\\preceq x.

The problem we aim to solve in this paper is to devise an ordering consensus protocol that is safe and live:

###### Definition 1 (Safety and Liveness of an Ordering Consensus Protocol).

An ordering consensus protocol is:

Safe if output sequences of correct miners are consistent.

Live if every message sent by a correct miner is eventually output by every correct miner with probability 1.

Here, we aim to devise safe and live ordering consensus protocols for models of distributed computing with two types of adaptive adversaries that can corrupt up to ff miners throughout the run: First, *Asynchrony*, in which the adversary controls the finite delay of every message. Second, *Eventual Synchrony (ES)*, in which there is a point in time, known as the *Global Stabilization Time (GST)*. After GST, the adversary controls the delivery time of messages sent between correct miners, but they must be delivered within a known bound Δ\\Delta. We further assume the adversary is computationally bounded and, therefore, cannot break cryptographic signatures.

We note that safety and liveness, combined with message uniqueness (e.g., a block in a blocklace, see next), imply the standard Byzantine Atomic Broadcast guarantees: Agreement, Integrity, Validity, and Total Order \[[9](#bib.bib9), [21](#bib.bib21)\]. Hence, protocols that address the problem defined here are in fact protocols for Byzantine Atomic Broadcast.

Next, we provide an overview of the Cordial Miners protocol, including the blocklace, the dissemination of blocks, and the local ordering of the blocks to a final sequence.

## 3 Cordial Miners Overview

![Refer to caption](2205.09174v6/Figs/goodcase.jpeg)

Figure 1: The blocklace data structure, equivocations, approval, and ratification. Four miners (red, green, blue, yellow). Each circle represents a block and each line a hash pointer to the left block. (A) A single wave consisting of five consecutive rounds. The green block in round rr with the halo is the leader block. Each of the highlighted blocks in yellow in rounds r+1r+1 and r+4r+4 have a path to the leader block, making it a final leader block. The blocks with a gray halo are ordered by τ\\tau when the leader block becomes final. (B) The red equivocates, with the top red block approved by the green block of the next round, the bottom red block approved by the yellow block of the next round, and the blue block of the next round, observing both equivocating red blocks, approves neither, and hence neither of the red blocks has the three approvals (including the red block itself) needed for ratification. (C) Here the blue block of the next round observes only the bottom red block and hence approves it, which together with the yellow block and the red block itself form a supermajority, and hence the bottom red block is ratified, but not the top one. (D) Here the blue miner equivocates in the next round, with the top blue block of the next round approving the top red block, which together with the green and red form a supermajority that ratifies it. Similarly, the bottom blue block, the yellow block, and the red (which is not illustrated) ratify the bottom red block. Indeed, with two equivocators (red and blue) out of four, an equivocation can be ratified.

In the Cordial Miners protocols, the miners jointly built the *blocklace* data structure, a partially-ordered counterpart of the totally-ordered blockchain. A blocklace created by four miners, each of a different color, is is illustrated in [Figure 1](#S3.F1 "In 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). The *depth* of a block in a blocklace is the length of the maximal path emanating from it, and a *round* of a blocklace consists of blocks of the same depth. A set of blocks by more than 12​(n+f)\\frac{1}{2}(n+f) miners is termed a *supermajority*; note that if f\=0f=0 then a supermajority is a simple majority. Correct miners are *cordial* in that they wait for round rr to attain a supermajority before contributing a block to round r+1r+1.

[Figure 1](#S3.F1 "In 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").A presents a blocklace constructed by four miners s.t. each column is a single round representing blocks from different miners, and each row in the same color consists of blocks from the same miner. Thus, each correct miner creates a single block in each round. Note that different miners can have different partial views of the blocklace, and the goal is to “converge” the order of the blocks to a consistent order for all the miners.

Each block holds a set of transactions as well as hash pointers (the edges in the DAG) to blocks of previous rounds. When a miner observes that round rr has attained a supermajority (is *cordial*) it creates a new block bb of round r+1r+1 with pointers to the *tips* of its blocklace up to round rr, which are the blocks in the blocklace with no incoming edges from blocks of depth up to rr. The tips must include a supermajority of blocks of round rr, but possibly also blocks of earlier rounds not already observed by the blocks received in round rr. (One block observes another if there is a path of pointers from one to the other.) E.g., if the figure represents the local blocklace of the red miner, then since round r+4r+4 is cordial, the red miner can create a new block bb in round r+5r+5 with pointers to all the blocks in round r+4r+4. The miner then sends bb to all other miners. The blocklace data structure is defined in [Section 4](#S4 "4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Next, we explain how Cordial Miners use the blocklace for the three algorithmic components of consensus: Dissemination, equivocation-exclusion, and ordering.

Dissemination. In the good case, dissemination is realized simply by each miner sending each new block to all other miners. However, faulty miners may fail to do so, possibly intentionally, and send new blocks only to some of the miners.

The principle of cordial dissemination \[[29](#bib.bib29)\] is: *Send to others blocks you know and think they need*. Its blocklace-based Byzantine-resilient implementation uses each block in the blocklace as an ack/nak message: A new block created by a correct miner pp points, directly or indirectly, to the blocks in pp’s local blocklace. It thus discloses the blocks known by pp at the time of its creation and, by omission, also of the blocks not yet known to pp. This way, a miner qq that receives pp’s block can send back to pp any block known to qq and not known to pp according to the disclosure made by pp’s block. E.g., the green block in round r+4r+4 serves as an ack message for all the blocks that it observes, including the red, green, and blue blocks in round r+3r+3. It also serves as a nak message for the yellow block of round r+3r+3. As an example of cordial dissemination, when the red miner sends the block it creates to the green miner in round r+5r+5, it will also send to the green miner the yellow block in round r+3r+3. The dissemination protocol is formally defined in [Section 6](#S6 "6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Equivocation exclusion. Two blocks b1,b2b\_{1},b\_{2} of the same miner are *equivocating* if neither observes the other, i.e., there is no path of pointers from b1b\_{1} to b2b\_{2} or from b2b\_{2} to b1b\_{1}. Since Cordial Miners do not use RB to disseminate blocks, the blocklace created by Cordial Miners may include equivocations created by Byzantine miners, which are later excluded when each miner locally orders the blocks in its blocklace to a sequence of final blocks. The Cordial Miners protocol uses supermajority approval to exclude equivocations s.t. for each set of equivocating blocks, at most, one is included in the final output. In addition, after detecting an equivocation, correct miners ignore the Byzantine miner by not including direct pointers to their blocks. Thus, a Byzantine miner that equivocates is eventually detected, which results in it eventually being ignored by all correct miners. Equivocation exclusion is part of the τ\\tau ordering function which is detailed in [Section 5](#S5 "5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Ordering. Ordering the partially-ordered blocklace can be achieved by topological sort of the DAG. The challenge is to ensure that all correct miners exclude equivocations and order the blocks identically so that they all produce the same total order. To this end, the blocklace is divided into *waves*, each consisting of several rounds, the number of which is different for ES and asynchrony (3 and 5 rounds per wave, respectively). E.g., [Figure 1](#S3.F1 "In 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").A depicts the asynchronous version which has 55 rounds in each wave.

For each wave, one of the miners is elected as the *leader*, and if the first round of the wave has a block produced by the leader, then it is the *leader block*. The figure depicts the green block in round rr in the green halo as the leader block of that wave. When a wave ends, i.e., when the last round of the wave is cordial, the leader block becomes *final* if it has sufficient blocks that *approve* it, namely, it is not equivocating and there is a supermajority where each block observes a supermajority that observes the leader block. The figure shows two supermajorities, highlighted in yellow, where each block in the supermajority of round r+4r+4 observes the supermajority of round r+1r+1. The supermajority in round r+1r+1 observes the leader block, and the leader block is not equivocating, making it final.

A final leader block bb serves as the “anchor” of the ordering function τ\\tau, which topologically sorts (while excluding equivocations) all the blocks observed by bb that have not been ordered yet. Thus, each time a wave ends with a final leader block, a portion of its preceding blocklace is ordered. In the figure, the blocks in round r−1r-1 with a grey halo are ordered when the leader block in round rr is final since it observes them. In case a wave ends with no final leader block, unordered blocks will be ordered when some subsequent wave ends with a final leader block. The full details of τ\\tau are in [Section 5](#S5 "5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

## 4 The Blocklace

A blocklace \[[28](#bib.bib28)\] is a partially-ordered counterpart of the totally-ordered blockchain data structure: In a blocklace, each block may contain a finite set of cryptographic hash pointers to previous blocks, in contrast to one pointer (or zero for the initial/genesis block) in a blockchain. Thus, a blocklace induces a DAG in which vertices represent its blocks and edges represent the pointers among its blocks. Next, we present the basic definitions of a blocklace, which appear as pseudocode in Alg. [1](#alg1 "Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). A formal mathematical description of these definitions appears in App. [A](#A1 "Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

### 4.1 Blocklace Basics

In addition to the set of miners Π\\Pi, we assume a given set of block payloads 𝒜\\mathcal{A}, typically sets of transactions, and a cryptographic hash function *hash*. A block consists of a payload a∈𝒜a\\in\\mathcal{A} and a set of hash pointers to previously created blocks, signed by its creator pp, in which case it is also referred to as a pp\-block (Def. [14](#Thmtheorem14 "Definition 14 (Block, Acknowledge). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). A block acknowledges another block if it contains a hash pointer to it, and is initial if the set of hash pointers is empty. A *blocklace* is a set of blocks (Def. [15](#Thmtheorem15 "Definition 15 (Blocklace). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Note that hash being cryptographic implies that a blocklace that includes a cycle cannot be effectively computed, and thus a blocklace BB induces a DAG, with blocks as vertices in BB and an edge among two vertices if the first includes a hash pointer to the second.

We say that a block bb observes another block b′b^{\\prime}, denoted b⪰b′b\\succeq b^{\\prime}, if there is a path from block bb to b′b^{\\prime}. If bb is a pp\-block in a blocklace BB, we say that miner pp observes b′b^{\\prime} in BB (Def. [16](#Thmtheorem16 "Definition 16 (≻, Observe). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). We note that ‘observe’ is the transitive closure of ‘acknowledge’. Each miner maintains a local blocklace of blocks it created and received. With a correct miner pp, any newly created pp\-block observes all the blocks in pp’s local blocklace.

The main violation a Byzantine miner qq can perform is an equivocation, by creating a pair of qq\-blocks that do not observe each other (See Fig. [1](#S3.F1 "Figure 1 ‣ 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").B). Such a miner qq is an equivocator (Def. [17](#Thmtheorem17 "Definition 17 (Equivocation, Equivocator). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). If the payloads of the two blocks are financial transactions, the equivocation may represent an attempt at double-spending. As any pp\-block is cryptographically signed by pp, an equivocation by pp is a volitional fault of pp, to which pp can be held accountable.

When a block bb observes another block b′b^{\\prime}, and does not observe any equivocating block (a block b′′b^{\\prime\\prime} that together with b′b^{\\prime} forms an equivocation), we say that bb approves b′b^{\\prime} (Def. [18](#Thmtheorem18 "Definition 18 (Approval). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Note that a block bb by a correct miner can observe two equivocating blocks b′,b′′b^{\\prime},b^{\\prime\\prime}, which means that bb approves neither b′b^{\\prime} nor b′′b^{\\prime\\prime} (See Fig. [1](#S3.F1 "Figure 1 ‣ 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").B). Block approval is not transitive. If b+b^{+} approves bb and bb approves b′b^{\\prime}, yet b+b^{+} also observes b′′b^{\\prime\\prime} (which together with b′b^{\\prime} forms an equivocation), then b+b^{+} does not approve b′b^{\\prime}.

A miner pp approves b′b^{\\prime} in a blocklace BB, if pp has a pp\-block bb in BB that approves b′b^{\\prime} (Def. [18](#Thmtheorem18 "Definition 18 (Approval). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). This holds even if pp has a later pp\-block b+b^{+} in BB that observes an equivocation b′b^{\\prime} and b′′b^{\\prime\\prime}. Namely, if miner pp approves b′b^{\\prime} in BB it also approves b′b^{\\prime} in any B′⊃BB^{\\prime}\\supset B.

A miner pp can approve both equivocating blocks b′b^{\\prime} and b′′b^{\\prime\\prime} in a blocklace BB, but only if pp is an equivocator (Obs. [30](#Thmtheorem30 "Observation 30 (Approving an Equivocation). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). An example will be if BB includes a pp\-block bb that observes b′b^{\\prime} but not b′′b^{\\prime\\prime}, and another block b+b^{+} that observes b′′b^{\\prime\\prime} but not b′b^{\\prime}, which can happen only if bb and b+b^{+} do not observe each other, namely form an equivocation (Fig. [1](#S3.F1 "Figure 1 ‣ 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").D).

The closure of a block bb, denoted \[b\]\[b\], is the set of all blocks observed by bb. The closure of a set of blocks BB, denoted \[B\]\[B\], is the union of the closures of the blocks in BB. A blocklace is closed if it does not contain ‘dangling pointers’ (a pointer to a block that is not in the blocklace). In other words, BB is closed if B\=\[B\]B=\[B\]. A block bb is a tip of a blocklace BB if there are no other blocks b′∈Bb^{\\prime}\\in B that observe bb (Def. [19](#Thmtheorem19 "Definition 19 (Closure, Closed, Tip). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). The depth (or round) of a block bb is the length of the longest path emanating from bb. The depth-dd prefix of BB, denoted B⁡(d)B(d), is the set of all blocks with depth less than or equal to dd. The depth-dd suffix of BB, denoted B¯​(d)\\bar{B}(d), is the set of all blocks with depth greater than dd (Def. [20](#Thmtheorem20 "Definition 20 (Block Depth/Round, Blocklace Prefix & Suffix). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

Algorithm 1 Cordial Miners: Blocklace Utilities. Code for miner pp

1: Local variables:

2:    struct block ​b\\textit{block }b: ⊳\\triangleright The structure of a block bb in a blocklace, Def. [14](#Thmtheorem14 "Definition 14 (Block, Acknowledge). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

3:       b.creatorb.\\textit{creator} – the miner that created bb

4:       b.payloadb.\\textit{payload} – a set of transactions

5:       b.pointersb.\\textit{pointers} – a possibly-empty set of hash pointers to other blocks

6:    blocklace ←{}\\leftarrow\\{\\} ⊳\\triangleright The local blocklace of miner pp

7: procedure create\_block(dd): ⊳\\triangleright Add to *blocklace* a new block bb pointing to its tips of depth ≤d\\leq d

8:    new bb ⊳\\triangleright Allocate a new block structure

9:    b.payload←payload​()b.\\textit{payload}\\leftarrow\\textit{payload}() ⊳\\triangleright e.g., dequeue a payload from a queue of proposals (aka mempool)

10:    b.creator←pb.\\textit{creator}\\leftarrow p

11:    b.pointers←h​a​s​h​(t​i​p​s)b.\\textit{pointers}\\leftarrow hash(tips), where tips are the tips of blocklace\_prefix(d)(d), at most two tips per miner ⊳\\triangleright Def. [19](#Thmtheorem19 "Definition 19 (Closure, Closed, Tip). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"); two-tips limitation to prevent a Byzantine miner from flooding the blocklace before being excommunicated

12:    return bb

13: procedure hash(bb): return hash value of bb ⊳\\triangleright Def. [14](#Thmtheorem14 "Definition 14 (Block, Acknowledge). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

14: procedure b⪰b′b\\succeq b^{\\prime}: ⊳\\triangleright Def. [16](#Thmtheorem16 "Definition 16 (≻, Observe). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), also refereed as bb observes b′b^{\\prime}

15:    return ∃b1,b2,…,bk∈blocklace\\exists b\_{1},b\_{2},\\ldots,b\_{k}\\in\\textit{blocklace}, k≥1k\\geq 1, s.t. b1\=bb\_{1}=b, bk\=b′b\_{k}=b^{\\prime} and ∀i∈\[k−1\]:hash​(bi+1)∈bi.pointers\\forall i\\in\[k-1\]\\colon\\textit{hash}(b\_{i+1})\\in b\_{i}.\\textit{pointers}

16: procedure closure(BB): return {b′∈blocklace:b∈B∧b⪰b′}\\{b^{\\prime}\\in\\textit{blocklace}:b\\in B\\wedge b\\succeq b^{\\prime}\\} ⊳\\triangleright Def. [19](#Thmtheorem19 "Definition 19 (Closure, Closed, Tip). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). Also referred to as \[B\]\[B\]. If B\={b}B=\\{b\\} is a singleton we use \[b\]\[b\] instead of \[{b}\]\[\\{b\\}\].

17: procedure equivocation(b1,b2b\_{1},b\_{2}): ⊳\\triangleright Def. [17](#Thmtheorem17 "Definition 17 (Equivocation, Equivocator). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), Fig. [1](#S3.F1 "Figure 1 ‣ 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").B

18:    return b1.creator\=b2.creator∧b1⋡b2∧b2⋡b1b\_{1}.\\textit{creator}=b\_{2}.\\textit{creator}\\wedge b\_{1}\\not\\succeq b\_{2}\\wedge b\_{2}\\not\\succeq b\_{1}

19: procedure equivocator(q,Bq,B): ⊳\\triangleright Def. [17](#Thmtheorem17 "Definition 17 (Equivocation, Equivocator). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), Fig. [1](#S3.F1 "Figure 1 ‣ 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"); more faults can be added

20:    return (∃b1,b2∈B:b1.creator\=b2.creator\=q∧equivocation(b1,b2))(\\exists b\_{1},b\_{2}\\in B:b\_{1}.\\textit{creator}=b\_{2}.\\textit{creator}=q\\wedge\\textit{equivocation}(b\_{1},b\_{2}))

21: procedure correct\_block(bb): ⊳\\triangleright See Def. [25](#Thmtheorem25 "Definition 25 (Cordial Block, Blocklace). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"); other conditions can be added

22:    return {b′.creator:hash(b′)∈b.pointers}\\{b^{\\prime}.\\textit{creator}:\\textit{hash}(b^{\\prime})\\in b.pointers\\} is a supermajority ∧¬equivocator(b.creator,\[b\])\\wedge\\lnot\\textit{equivocator}(b.\\textit{creator},\[b\])

23: procedure approves(b,b1b,b\_{1}): return b1∈\[b\]∧∀b2∈\[b\]:¬b\_{1}\\in\[b\]\\wedge\\forall b\_{2}\\in\[b\]:\\lnotequivocation(b1,b2)(b\_{1},b\_{2}) ⊳\\triangleright Def. [18](#Thmtheorem18 "Definition 18 (Approval). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), Fig. [1](#S3.F1 "Figure 1 ‣ 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").C

24: procedure ratifies(B1,b2B\_{1},b\_{2}): ⊳\\triangleright Def. [22](#Thmtheorem22 "Definition 22 (Ratified and Super-Ratified Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), Fig. [1](#S3.F1 "Figure 1 ‣ 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").C

25:    return {b.creator:b∈\[B1\]∧approves(b,b2)}\\{b.\\textit{creator}:b\\in\[B\_{1}\]\\wedge\\textit{approves}(b,b\_{2})\\} is a supermajority

26: procedure super\_ratifies(B1,b2B\_{1},b\_{2}): ⊳\\triangleright Def. [22](#Thmtheorem22 "Definition 22 (Ratified and Super-Ratified Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), Fig. [1](#S3.F1 "Figure 1 ‣ 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").A

27:    return {b.creator:b∈\[B1\]∧ratifies(\[b\],b2)}\\{b.\\textit{creator}:b\\in\[B\_{1}\]\\wedge\\textit{ratifies}(\[b\],b\_{2})\\} is a supermajority

28: procedure depth(bb):

29:    return max  {k:∃b′∈\\{k:\\exists b^{\\prime}\\in blocklace with a path from bb to b′b^{\\prime} of length kk}. ⊳\\triangleright Def. [20](#Thmtheorem20 "Definition 20 (Block Depth/Round, Blocklace Prefix & Suffix). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

30: procedure blocklace\_prefix(dd): return {b∈blocklace:depth​(b)≤d}\\{b\\in\\textit{blocklace}:\\textit{depth}(b)\\leq d\\} ⊳\\triangleright Def. [20](#Thmtheorem20 "Definition 20 (Block Depth/Round, Blocklace Prefix & Suffix). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

31: procedure cordial\_round(rr):

32:    return {b.creator:b∈blocklace∧depth(b)\=r}\\{b.\\textit{creator}:b\\in\\textit{blocklace}\\wedge\\textit{depth}(b)=r\\} is a supermajority ⊳\\triangleright Def. [25](#Thmtheorem25 "Definition 25 (Cordial Block, Blocklace). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

33: procedure completed\_round(i):

34:    return max⁡{r:cordial\_round​(r)}\\max~\\{r:\\textit{cordial\\\_round}(r)\\}

35: procedure last\_block(pp): ⊳\\triangleright The pp\-block with the highest round

36:    return b∈b​l​o​c​k​l​a​c​eb\\in blocklace s.t. b.creator\=p∧(∀b′∈blocklace:b′.creator\=p⟹b′⊁b)b.\\textit{creator}=p\\wedge(\\forall b^{\\prime}\\in blocklace:b^{\\prime}.\\textit{creator}=p\\implies b^{\\prime}\\not\\succ b)

### 4.2 Blocklace Safety

Note that as equivocation is a fault, at most ff miners may equivocate. Ensuring that the majority of correct miners approve a given block, requires approval from a supermajority of all miners, that is more than n+f2\\frac{n+f}{2} of the miners. A set of blocks is a supermajority if it includes blocks from a supermajority of miners (Def. [21](#Thmtheorem21 "Definition 21 (Supermajority). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). We show that there cannot be a supermajority approval of an equivocation (Lem. [31](#Thmtheorem31 "Lemma 31 (No Supermajority Approval for Equivocation). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

A block bb ratifies a block b′b^{\\prime} if the closure of bb includes a supermajority of blocks that approve b′b^{\\prime}. A set of blocks BB super-ratifies a block b′b^{\\prime}, if it includes a supermajority of blocks that ratify b′b^{\\prime} (Def. [22](#Thmtheorem22 "Definition 22 (Ratified and Super-Ratified Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") and Fig. [1](#S3.F1 "Figure 1 ‣ 3 Cordial Miners Overview ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

The rounds in the blocklace are divided into waves, such that each wave has a fixed length of w≥1w\\geq 1, defined as the wavelength (Def. [23](#Thmtheorem23 "Definition 23 (Wavelength, Leader Selection Function, Leader Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), and the wave consists of all the blocks in those rounds. E.g., if the wavelength is 2, then the blocks in rounds 0 and 1 are in the first wave, and the blocks in rounds 3 and 4 are included in the second wave. We assume the existence of a leader selection function that chooses randomly for each wave ww a single miner who will be the leader of that wave. A pp\-block bb is a leader block of wave ww if pp is chosen as the leader of ww and the blocklace contains bb in the first round of ww. E.g., if miner pp is chosen as the leader of the first wave, and pp has a block bb in round 00, then bb is the leader block of the first wave. We use leader blocks as part of the ordering function τ\\tau which is detailed in [Section 5](#S5 "5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") and is used to totally order the blocklace.

Note that an equivocating leader can have several leader blocks in the same round. A leader block is final (Def. [24](#Thmtheorem24 "Definition 24 (Final Leader Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) if it is super-ratified within its wave, i.e., we say that the leader block bb of round rr is final if the blocklace prefix B⁡(r+w−1)B(r+w-1) super-ratifies bb.

The following notion of blocklace safety is the basis for the monotonicity of the blocklace ordering function τ\\tau, and hence for the safety of a protocol that uses τ\\tau for blocklace ordering.

###### Definition 2 (Blocklace Leader Safety).

A blocklace BB is leader-safe if every final leader block in BB is ratified by every subsequent leader block in BB.

A sufficient condition for blocklace leader safety is for every block in the blocklace to acknowledge blocks by at least a supermajority of miners (see Fig. [2](#A2.F2 "Figure 2 ‣ Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Such a block is a cordial block and a blocklace with only cordial blocks is a cordial blocklace (Def. [25](#Thmtheorem25 "Definition 25 (Cordial Block, Blocklace). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). A correct block bb is a pp\-block s.t. bb is a cordial block and pp does not equivocate in \[b\]\[b\] (Def [26](#Thmtheorem26 "Definition 26. ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

###### Proposition 3.

A cordial blocklace is leader-safe.

### 4.3 Blocklace Liveness

Next, we discuss conditions that ensure blocklace leader liveness.

###### Definition 4 (Blocklace Leader Liveness).

A blocklace BB is leader-live if for every block b∈Bb\\in B by a miner not equivocating in BB there is a final leader block in BB that observes bb.

Given a blocklace, a set of miners PP is (mutually) disseminating if every block by a miner in PP is eventually observed by every miner in PP (Def. [27](#Thmtheorem27 "Definition 27 (Disseminating). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). We show that dissemination is unbounded, meaning that if a set of miners PP is disseminating in BB then BB is infinite, and in particular any suffix of BB has blocks from any member of PP (Obs. [32](#Thmtheorem32 "Observation 32 (Dissemination is Unbounded). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). It follows that a cordial blocklace with a non-equivocating and disseminating supermajority of miners is leader-live (Fig. [3](#A2.F3 "Figure 3 ‣ Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

###### Proposition 5 (Blocklace Leader Liveness Condition).

If B⊂ℬB\\subset\\mathcal{B} is a cordial blocklace with a non-equivocating and disseminating supermajority of miners, such that for every r\>0r>0 there is a final leader block of round r′\>rr^{\\prime}>r, then BB is leader-live.

## 5 Blocklace Ordering with τ\\tau

Algorithm 2 Cordial Miners: Ordering of a Blocklace with τ\\bm{\\tau}  
pseudocode for miner p∈Πp\\in\\Pi, including Algorithms [1](#alg1 "Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") & [4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

37: Local Variable:

38:    outputBlocks←{}\\textit{outputBlocks}\\leftarrow\\{\\}

39: procedure τ⁡()\\tau(): ⊳\\triangleright Called from [62](#algx3.l62 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

40:    τ′​(last\_final\_leader​())\\tau^{\\prime}(\\textit{last\\\_final\\\_leader}())

41: procedure τ′\\tau^{\\prime}(b1b\_{1}):

42:    if b1∈outputBlocks∨b1\=∅b\_{1}\\in\\textit{outputBlocks}\\vee b\_{1}=\\emptyset then return    

43:    b2←previous\_ratified\_leader​(b1)b\_{2}\\leftarrow\\textit{previous\\\_ratified\\\_leader}(b\_{1})

44:    τ′​(b2)\\tau^{\\prime}(b\_{2}) ⊳\\triangleright Recursive call to τ′\\tau^{\\prime}

45:    output xsort​(b1,\[b1\]∖\[b2\])\\textit{xsort}(b\_{1},\[b\_{1}\]\\setminus\[b\_{2}\]) ⊳\\triangleright Output a new equivocation-free suffix

46:    outputBlocks←outputBlocks∪xsort​(b1,\[b1\]∖\[b2\])\\textit{outputBlocks}\\leftarrow\\textit{outputBlocks}\\cup\\textit{xsort}(b\_{1},\[b\_{1}\]\\setminus\[b\_{2}\])

47: procedure xsort(b,Bb,B): ⊳\\triangleright Exclude equivocations and sort

48:    return topological sort wrt ≻\\succ of the set {b′∈B:approves​(b,b′)}\\{b^{\\prime}\\in B:\\textit{approves}(b,b^{\\prime})\\}

49: procedure previous\_ratified\_leader(b1b\_{1}):

50:    return argb∈R​max⁡depth​(b)\\textit{arg}\_{b\\in R}\\max~\\textit{depth}(b)

51:    where R\={b∈\[b1\]∖{b1}:b.creator\=leader(depth(b))∧ratifies(\[b1\],b)}R=\\{b\\in\[b\_{1}\]\\setminus\\{b\_{1}\\}:b.\\textit{creator}=\\textit{leader}(\\textit{depth}(b))\\wedge\\textit{ratifies}(\[b\_{1}\],b)\\}

52: procedure last\_final\_leader​()\\textit{last\\\_final\\\_leader}(): ⊳\\triangleright Fig. [2](#A2.F2 "Figure 2 ‣ Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

53:    return argu∈U​max⁡depth​(u)\\textit{arg}\_{u\\in U}\\max~\\textit{depth}(u) where

54:    U\={b∈blocklace:b.creator\=leader(depth(b))∧final\_leader(b)}U=\\{b\\in\\textit{blocklace}:b.\\textit{creator}=\\textit{leader}(\\textit{depth}(b))\\wedge\\textit{final\\\_leader}(b)\\}

55: procedure final\_leader(bb): ⊳\\triangleright Def. [24](#Thmtheorem24 "Definition 24 (Final Leader Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

56:    return super-ratifies​((blocklace\_prefix​(depth​(b)+w−1),b)CLOSE\\textit{super-ratifies}((\\textit{blocklace\\\_prefix}(\\textit{depth}(b)+w-1),b)

57: procedure leader()() (Def. [23](#Thmtheorem23 "Definition 23 (Wavelength, Leader Selection Function, Leader Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) and wavelength ww are defined in Alg. [4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Here we present a deterministic function τ\\tau that, given a blocklace BB, employs final leaders to topologically sort BB into a sequence of its blocks, respecting ≻\\succ. The intention is that in a blocklace-based ordering consensus protocol, each miner would use τ\\tau to locally convert their partially-ordered blocklace into the totally-ordered output sequence of blocks.

The section concludes with Theorem [8](#Thmtheorem8 "Theorem 8 (Sufficient Condition for the Safety and Liveness of a Blocklace-Based Ordering Consensus Protocol). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), which provides sufficient conditions for the safety and liveness of any blocklace-based ordering consensus protocol that employs τ\\tau. The proof method is novel, in that it does not argue operationally, about events and their order in time, but rather about the properties of an infinite data structure – the blocklace. In the following section, we prove that the Cordial Miners protocols, which employ Alg. [2](#alg2 "Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") that realizes τ\\tau, satisfy these conditions, and thus establish their safety and liveness. The operation of τ\\tau is depicted in Fig. [4](#A2.F4 "Figure 4 ‣ Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

We show that τ\\tau is monotonic, in that if it is repeatedly called with an ever-increasing blocklace then its output is an ever-increasing sequence of blocks. This monotonicity ensures finality, as it implies that any output will not be undone by a subsequent output. With τ\\tau, final leaders are the anchors of finality in the growing chain, each ‘writes history’ backward till the preceding final leader.

The following recursive ordering function τ\\tau maps a blocklace into a sequence of blocks, excluding equivocations along the way. Formally, the entire sequence is computed backward from the last super-ratified leader, afresh by each application of τ\\tau. Practically, a sequence up to a super-ratified leader is final (Prop. [9](#Thmtheorem9 "Proposition 9 (Monotonicity of 𝜏). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) and hence can be cached, allowing the next call to τ\\tau with a new super-ratified leader to be computed backward only till the previously-cached super-ratified leader, while producing as output all the blocks approved by the new super-ratified leader (the approval ensures that the new fragment does not introduce equivocations) that are not observed by the previously-cached final leader.

###### Definition 6 (τ\\tau).

We assume a fixed topological sort function xsort​(b,B)\\textit{xsort}(b,B) (exclude and sort) that takes a block bb and a blocklace BB, and returns a sequence consistent with ≻\\succ of all the blocks in BB that are approved by bb. The function τ:2ℬ→ℬ∗\\tau:2^{\\mathcal{B}}\\xrightarrow{}\\mathcal{B}^{\*} is defined for a blocklace B⊂ℬB\\subset\\mathcal{B} backward, from the last output element to the first, as follows: If BB has no final leaders then τ⁡(B):=Λ\\tau(B):=\\Lambda (empty sequence). Else, let bb be the last final leader in BB. Then τ​(B):=τ′​(b)\\tau(B):=\\tau^{\\prime}(b), where τ′\\tau^{\\prime} is defined recursively:

τ′​(b):={xsort​(b,\[b\])​ if \[b\] has no leader ratified by b, else τ′​(b′)⋅xsort​(b,\[b\]∖\[b′\])​ if b′ is the last leader zzzzzzzzzzzzzzzzzzzzzzzzzzratified by b in \[b\]\\tau^{\\prime}(b):=\\begin{cases}\\textit{xsort}(b,\[b\])\\text{\\ \\ \\ \\ \\ if $\[b\]$ has no leader ratified by $b$, else }\\\\ \\tau^{\\prime}(b^{\\prime})\\cdot\\textit{xsort}(b,\[b\]\\setminus\[b^{\\prime}\])\\text{\\ \\ if $b^{\\prime}$ is the last leader }\\\\ \\text{\\phantom{zzzzzzzzzzzzzzzzzzzzzzzzzz}ratified by $b$ in $\[b\]$}\\end{cases}

Note that when τ′\\tau^{\\prime} is called with a leader bb, it makes a recursive call with a leader ratified by bb, which is not necessarily super-ratified.

A pseudo-code implementation of τ\\tau is presented as Alg. [2](#alg2 "Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). The algorithm is a literal implementation of the mathematics described above: It maintains *outputBlocks* that includes the prefix of the output τ\\tau that has already been computed. Upon adding a new block to its blocklace (Line [39](#algx2.l39 "In Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), it computes the most recent final leader b1b\_{1} according to Definition [24](#Thmtheorem24 "Definition 24 (Final Leader Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), and applies τ\\tau to it, realizing the mathematical definition of τ\\tau (Def. [6](#Thmtheorem6 "Definition 6 (𝜏). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), with the optimization, discussed above, that a recursive call with a block that was already output is returned. Hence the following proposition:

###### Proposition 7 (Correct implementation of τ\\tau).

The procedure τ\\tau in Alg. [2](#alg2 "Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") correctly implements the function τ\\tau in Definition [6](#Thmtheorem6 "Definition 6 (𝜏). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

The following theorem provides a sufficient condition for the safety and liveness (Def. [1](#Thmtheorem1 "Definition 1 (Safety and Liveness of an Ordering Consensus Protocol). ‣ 2 Model and Problem Definition ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) of any blocklace ordering consensus protocol that employs τ\\tau, and thus offers conditions for solving the problem defined in [Section 2](#S2 "2 Model and Problem Definition ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"):

###### Theorem 8 (Sufficient Condition for the Safety and Liveness of a Blocklace-Based Ordering Consensus Protocol).

Assume a given blocklace-based consensus protocol that employs τ\\tau for ordering. If in every run of the protocol all correct miners have in the limit the same blocklace BB that is leader-safe and leader-live, then the protocol is safe and live.

Next, we provide a proof outline of [Theorem 8](#Thmtheorem8 "Theorem 8 (Sufficient Condition for the Safety and Liveness of a Blocklace-Based Ordering Consensus Protocol). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

τ\\tau Safety. A safe blocklace ensures a final leader is ratified by any subsequent leader, final or not. Hence the following:

###### Proposition 9 (Monotonicity of τ\\tau).

Let BB be a cordial blocklace with a supermajority of correct miners. Then τ\\tau is monotonic wrt the superset relation among closed subsets of BB, namely for any two closed blocklaces B2⊆B1⊆BB\_{2}\\subseteq B\_{1}\\subseteq B, τ⁡(B2)⪯τ⁡(B1)\\tau(B\_{2})\\preceq\\tau(B\_{1}).

The following proposition ensures that if there is a supermajority of correct miners, which jointly create a cordial blocklace, then the output sequences computed by any two miners based on their local blocklaces would be consistent. This establishes the safety of τ\\tau under these conditions.

###### Proposition 10 (τ\\tau Safety).

Let BB be a blocklace with a supermajority of correct miners. Then for every B1,B2⊆BB\_{1},B\_{2}\\subseteq B, τ⁡(B1)\\tau(B\_{1}) and τ⁡(B2)\\tau(B\_{2}) are consistent.

τ\\tau Liveness. While τ\\tau does not output all the blocks in its input, as blocks not observed by the last final leader in its input are not in its output, the following observation and proposition set the conditions for τ\\tau liveness:

###### Observation 11 (τ\\tau output).

If a pp\-block b∈Bb\\in B by a miner pp not equivocating in BB is observed by a final leader in BB, then b∈τ⁡(B)b\\in\\tau(B).

###### Proposition 12 (τ\\tau Liveness).

Let B1⊂B2⊂…B\_{1}\\subset B\_{2}\\subset\\ldots be a sequence of finite blocklaces for which B\=⋃i≥1BiB=\\bigcup\_{i\\geq 1}B\_{i} is a cordial leader-live blocklace. Then for every block b∈Bb\\in B by a correct miner in BB there is an i≥1i\\geq 1 such that b∈τ⁡(Bi)b\\in\\tau(B\_{i}).

Thus, we conclude that the safety and liveness properties of τ\\tau carry over to Alg. [2](#alg2 "Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Next, we prove that the two Cordial Miners consensus protocols—for eventual synchrony and asynchrony—satisfy the conditions of Theorem [8](#Thmtheorem8 "Theorem 8 (Sufficient Condition for the Safety and Liveness of a Blocklace-Based Ordering Consensus Protocol). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), and hence are safe and live.

## 6 The Cordial Miners Protocols

Algorithm 3 Cordial Miners: Blocklace-Based Dissemination  
Code for miner pp, including Algorithms [1](#alg1 "Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), [2](#alg2 "Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") & [4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

58: Local variables:

59:    r←0r\\leftarrow 0 ⊳\\triangleright The current round of pp, see Def. [20](#Thmtheorem20 "Definition 20 (Block Depth/Round, Blocklace Prefix & Suffix). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

60: upon receipt of b:b.pointers⊆hash​(blocklace)∧correct\_block​(b)b:\\textit{b.pointers}\\subseteq\\textit{hash}(\\textit{blocklace})\\wedge\\textit{correct\\\_block}(b) do ⊳\\triangleright Received ‘out of order’ blocks are buffered; incorrect blocks are ignored

61:    blocklace←blocklace∪{b}\\textit{blocklace}\\leftarrow\\textit{blocklace}~\\cup\\{b\\}

62:    τ⁡()\\tau() ⊳\\triangleright Defined in [39](#algx2.l39 "In Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

63:    if completed\_round​()≥r\\textit{completed\\\_round}()\\geq r then ⊳\\triangleright Defined in [33](#algx1.l33 "In Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), line [33](#algx1.l33 "In Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

64:     es\_advance\_round​()\\textit{es\\\_advance\\\_round}() ⊳\\triangleright Advance round conditions for ES, no-op for asynchrony. Defined in [Algorithm 4](#alg4 "In 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

65:     b←create\_block​(completed\_round​())b\\leftarrow\\textit{create\\\_block}(\\textit{completed\\\_round}())

66:     r←depth​(b)r\\leftarrow\\textit{depth}(b) ⊳\\triangleright Advance round

67:     for q∈Πq\\in\\Pi do ⊳\\triangleright Cordial Dissemination

68:       send {b}∪blocklace\_prefix​(r−2)∖\[last\_block​(q)\]\\{b\\}\\cup\\textit{blocklace\\\_prefix}(r-2)\\setminus\[\\textit{last\\\_block}(q)\] to qq        

So far, we presented the blocklace and how a blocklace can be totally ordered using τ\\tau. Next, we show how miners disseminate their blocks to form a blocklace.

The shared components of the Cordial Miners protocols are specified via pseudocode in Algs. [1](#alg1 "Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") (blocklace utilities), [2](#alg2 "Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") (the ordering function τ\\tau), and [3](#alg3 "Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") (dissemination). Alg. [4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") details the differences between the Cordial Miners protocols for ES and asynchrony. We begin by explaining the dissemination protocol.

Algorithm 4 Cordial Miners: Specific Utilities. Code for miner pp.

[4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").1 Procedures for Asynchrony

69: w←5w\\leftarrow 5

70: procedure es\_advance\_round​()\\textit{es\\\_advance\\\_round}(): ⊳\\triangleright No-op

71:    return

72: procedure leader(dd):

73:    if d​ mod ​w\=0d\\text{ mod }w=0 then

74:     return q∈Πq\\in\\Pi via a shared coin tossed at round d+w−1d+w-1

75:    else

76:     return ⊥\\bot    

[4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").2 Procedures for Eventual Synchrony

77: w←3w\\leftarrow 3

78: procedure es\_advance\_round():

79:    return max⁡r:cordial\_round​(r)∧\\max~r:\\textit{cordial\\\_round}(r)~\\wedge ⊳\\triangleright Last cordial round, [32](#algx1.l32 "In Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

80:    ((r​ mod ​w\=0⟹r\\text{ mod }w=0\\implies ⊳\\triangleright First round of the wave, leader is included in the round.

81:    ∃b∈blocklace:(leader(r)\=b.creator)∧\\exists b\\in\\textit{blocklace}:(\\textit{leader}(r)=b.\\textit{creator})~\\wedge

82:    ((r​ mod ​w\=1⟹CLOSECLOSE((r\\text{ mod }w=1\\implies ⊳\\triangleright Second round of the wave, round r−1r-1 leader is ratified by round rr blocks

83:    ∃b∈blocklace:(leader(r−1)\=b.creator∧\\exists b\\in\\textit{blocklace}:(\\textit{leader}(r-1)=b.\\textit{creator}~\\wedge OPENOPENratifies​(blocklace\_prefix​(r),b)))∧\\textit{ratifies}(\\textit{blocklace\\\_prefix}(r),b)))~\\wedge

84:    ((r​ mod ​w\=2⟹CLOSECLOSE((r\\text{ mod }w=2\\implies ⊳\\triangleright Third round, round r−2r-2 leader is super-ratified by rr blocks

85:    ∃b∈blocklace:(leader(r−2)\=b.creator∧\\exists b\\in\\textit{blocklace}:(\\textit{leader}(r-2)=b.\\textit{creator}~\\wedge OPENOPENsuper-ratifies​(blocklace\_prefix​(r),b)))\\textit{super-ratifies}(\\textit{blocklace\\\_prefix}(r),b)))

86:    OPEN∨timeout)\\vee~\\textit{timeout}) ⊳\\triangleright Or timeout occurred. timeout is measured from when round rr is cordial. This is pp’s estimation of Δ\\Delta.

87: procedure leader(dd):

88:    if d​ mod ​w\=0d\\text{ mod }w=0 then

89:     return q∈Πq\\in\\Pi selected deterministically

90:    else

91:     return ⊥\\bot    

Property

Asynchrony

Eventual Synchrony

Wavelength w\\bm{w}:

55 (Line [69](#algx4.l69 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"))

33 (Line [77](#algx5.l77 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"))

Leader Selection:

Retrospective via coin toss (Line [72](#algx4.l72 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"))

Prospective by a known order  
(Line [87](#algx5.l87 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"))

Condition for advancing round:

None (Line [70](#algx4.l70 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"))

timeout or finality conditions  
(Line [78](#algx5.l78 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"))

Table 2: Cordial Miners’ differences between Eventual Synchrony and Asynchrony

### 6.1 Dissemination (Alg. [3](#alg3 "Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"))

A correct block is buffered until it has no dangling pointers, and then it is received (Line [60](#algx3.l60 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). We prove that an equivocating miner eventually can only produce incorrect blocks (Def. [26](#Thmtheorem26 "Definition 26. ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) and therefore is eventually excommunicated by all correct miners. After including a received block in its local blocklace, a miner calls τ\\tau (Line [62](#algx3.l62 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), which outputs new blocks if the received block results in the blocklace having a new final leader block.

If there is a new completed round in the blocklace (Line [63](#algx3.l63 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), the miner creates a new block bb (Line [65](#algx3.l65 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), computes the new round (Line [66](#algx3.l66 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), and sends bb to its fellow miners. The package sent to miner qq contains any blocks up to the previous round that pp knows that qq might not know, based on the last block received from qq (Line [68](#algx3.l68 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Note that as the network is reliable, send is defined to be idempotent, namely to send each block to each miner at most once.

We note that there is a tradeoff between latency and message complexity, and there is a range of possible optimizations and heuristics. These are discussed in [Appendix D](#A4 "Appendix D Future Direction and Optimizations ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). Here, we present a version of Cordial Miners protocols in which every block is communicated among every pair of correct miners in the worst case.

### 6.2 Specific utilities (Alg. [4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"))

Overview. There are several differences between the Cordial Miners protocols for ES and asynchrony, which are specified in Alg. [4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") and summarized in Tab. [2](#S6.T2 "Table 2 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

First, in asynchrony, each wave consists of 55 rounds, and the leader block in the first round is chosen randomly using a shared coin tossed in the last round of the wave, i.e., the leader election is retrospective. We expand on the coin below. In ES, each wave has 33 rounds, and the leader block is elected in advance using any deterministic prospective method, e.g., round robin.

The reason a wave in asynchrony is longer is to counter the adversary: If the adversary knows in advance the leader block in the first round of the wave, it can manipulate block arrival times s.t. a wave with a final leader block will never happen. We prove that by using such coin at the last round of the wave, the adversary cannot affect the probability the the leader block is final. In ES, a wave consists of three rounds. We prove that this is sufficient to allow super-ratification of the leader block, making it final in case the leader is an honest miner.

Another difference is if an honest miner waits before proceeding to the next round when the current round becomes cordial. In asynchrony, the miner proceeds immediately to the next round when it is cordial (Line [70](#algx4.l70 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). In ES, a miner advances to the next round after a round either if timeout passes, or conditions for leader block finality occur (Line [78](#algx5.l78 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). The conditions are: if this is the first round of a wave, then the round contains the leader block (Line [80](#algx5.l80 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). If this is the second round, then the miner advances immediately if the round has a supermajority of blocks that ratifies the leader block (Line [82](#algx5.l82 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), and lastly, if the third round of a wave has a supermajority of blocks that super-ratifies the leader block (Line [84](#algx5.l84 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). These conditions are to prevent the adversary from ordering the messages after GST, in particular, the leader block and the blocks that super-ratify it, as the leader is known in advance.

Algorithm walkthrough. The leader (Lines [72](#algx4.l72 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), [87](#algx5.l87 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) procedure, which is called as part of τ\\tau, is an implementation of Def. [23](#Thmtheorem23 "Definition 23 (Wavelength, Leader Selection Function, Leader Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

The Cordial Miners asynchrony protocol, for which w\=5w=5 (Line [69](#algx4.l69 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), elects leaders retrospectively using a shared random coin. To elect the leader of round rr, when r​ mod ​5\=0r\\text{ mod }5=0, all correct miners toss the coin in round r+3r+3 and know in round r+4r+4 the elected leader of round rr, as follows. We assume two shared random coin functions: toss\_coin and combine\_tosses. The function toss\_coin​(ps,d)\\textit{toss\\\_coin}(p\_{s},d) takes the secret key psp\_{s} of miner p∈Πp\\in\\Pi and a round number d≥0d\\geq 0 as input, and produces pp’s share of the coin of round dd, sp,ds\_{p,d}, as output. If the protocol needs to compute the shared random coin for round dd, then sp,ds\_{p,d} is incorporated in the payload of the dd\-depth pp\-block of every correct miner pp. The function combine\_tosses​(S,d)\\textit{combine\\\_tosses}(S,d) takes a set SS of shares sp,ds\_{p,d}, d≥0d\\geq 0, for which |{p:sp,d∈S}|\>f+1|\\{p:s\_{p,d}\\in S\\}|>f+1, and returns a miner q∈Πq\\in\\Pi. The properties of a similar function were presented in \[[21](#bib.bib21)\], which details how to implement such a coin as part of a distributed blocklace-like structure.

We formally define the shared coin in definition [28](#Thmtheorem28 "Definition 28 (Shared Random Coin). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). Examples of such a coin implementation using threshold signatures \[[6](#bib.bib6), [23](#bib.bib23), [31](#bib.bib31)\] are in \[[10](#bib.bib10), [21](#bib.bib21)\]. The ES protocol elects leaders in a prospective manner via a fixed deterministic function, e.g., round-robin between the miners.

### 6.3 Correctness Proof Outline

The main theorem we prove is the following:

###### Theorem 13 (Cordial Miners Protocols Safety and Liveness).

The protocols for eventual synchrony and asynchrony specified in Algs. [1](#alg1 "Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), [2](#alg2 "Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), [3](#alg3 "Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), & [4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") are safe and live (Def. [1](#Thmtheorem1 "Definition 1 (Safety and Liveness of an Ordering Consensus Protocol). ‣ 2 Model and Problem Definition ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

We argue that in the limit the blocklaces of correct miners that participate in a run of a Cordial Miners protocol are identical, are leader-safe, and leader-live.

A formal description of blocklace-based protocols in terms of asynchronous multiagent transition systems with faults has been carried out in reference \[[28](#bib.bib28)\]. Here, we employ pseudocode, presented in Algorithms [1](#alg1 "Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), [2](#alg2 "Algorithm 2 ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), [3](#alg3 "Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") & [4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") to describe the correct behaviors of a miner in a protocol, and discuss only informally the implied multiagent transition system and its computations. A run of the protocol by the miners Π\\Pi results in a sequence of configurations ρ\=c0,c1,…\\rho=c\_{0},c\_{1},\\ldots, each encoding the local state of each miner. A miner is *correct* in a run ρ\\rho if it behaves according to the pseudocode during ρ\\rho, *faulty* otherwise. As stated above, we assume that there are at most f<n/3f<n/3 faulty miners in any run. We use Bp​(c)B\_{p}(c) to denote the local blocklace of miner p∈Πp\\in\\Pi in configuration cc, Bp​(ρ)B\_{p}(\\rho) to denote the blocklace of miner pp in the limit, Bp​(ρ):=⋃c∈ρBp​(c)B\_{p}(\\rho):=\\bigcup\_{c\\in\\rho}B\_{p}(c), and B⁡(ρ)B(\\rho) to denote the unions of the blocklaces of all correct miners in the limit, B⁡(ρ):=⋃p∈PBp​(ρ)B(\\rho):=\\bigcup\_{p\\in P}B\_{p}(\\rho), where P⊆ΠP\\subseteq\\Pi is the set of correct miners in run ρ\\rho.

We start by showing miner asynchrony (not to be confused with the model of asynchrony), that is, if a miner can create a block, then it can still create it regardless of additional blocks it receives from other miners (Prop. [34](#Thmtheorem34 "Proposition 34 (Miner Asynchrony). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Miner asynchrony combined with the standard notion of *fairness*, that a transition that is enabled infinitely often in a run is eventually taken in the run, implies that once a Cordial Miners block creation transition is enabled then it will eventually be taken (Prop. [35](#Thmtheorem35 "Proposition 35 (Miners Liveness). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). We conclude that every miner pp correct in a run produces the blocklace of the run, namely Bp​(ρ)\=B​(ρ)B\_{p}(\\rho)=B(\\rho) (Prop. [36](#Thmtheorem36 "Proposition 36 (Cordial Miners Dissemination). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). We can now argue the safety of the Cordial Miners protocols (Prop. [37](#Thmtheorem37 "Proposition 37 (Cordial Miners Protocol Safety). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

We now proceed to argue the liveness of the Cordial Miners protocols. We show that the Cordial Miners eventual synchrony protocol is leader-live with probability 1 (Prop. [38](#Thmtheorem38 "Proposition 38 (Leader-Liveness of Cordial Miners Eventual Synchrony Protocol). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). We note that, following GST, the probability of a leader block being final is at least |P|n\\frac{|P|}{n}, where P⊆ΠP\\subseteq\\Pi is the set of correct miners, and given that w\=3w=3, if |P|n\>23\\frac{|P|}{n}>\\frac{2}{3}, then the expected latency is at most 3/(2/3)\=4.53/(2/3)=4.5 rounds.

The next proposition ensures that all correct miners eventually repel all equivocators and stop observing their blocks. We define an equivocator-repelling block recursively (Def. [29](#Thmtheorem29 "Definition 29 (Equivocator-Repelling). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), through the set of blocks BB that it acknowledges, terminating in an initial block, where B\=∅B=\\emptyset. Note that a block (or blocklace) that is equivocator-repelling may include equivocations, for example, two equivocating blocks each observed by a different block in BB. However, once an equivocation by miner qq is observed by a block bb, qq would be repelled: Any block that observes bb would not acknowledge any qq\-block, preventing any further qq\-blocks from joining the blocklace. Also note that equivocators are eventually excommunicated since they eventually cannot produce correct blocks (Prop. [39](#Thmtheorem39 "Proposition 39 (Equivocators-Free Suffix). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

Lemma [40](#Thmtheorem40 "Lemma 40 (Blocklace Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") claims the existence of a blocklace common core, which is the blocklace-variant of the notion of a common core that appears in \[[3](#bib.bib3), [17](#bib.bib17)\]. Its proof is an adaptation to the cordial blocklace setting of the common core proof in \[[17](#bib.bib17)\], which in turn is derived from the proof of get-core in \[[3](#bib.bib3)\]. Fig. [5](#A2.F5 "Figure 5 ‣ Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") illustrates its proof as well as the proof of the following Corollary [41](#Thmtheorem41 "Corollary 41 (Super-Ratified Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), about the existence of a super-ratified common core.

The lemma and corollary require an equivocators-free section of the blocklace, which may be the entire equivocation-free suffix of the blocklace as in the proof. But the proof also holds if there is a long enough stretch of rounds without equivocation, in which case a common core also exists. We conclude that if a Cordial Miners protocol relies on the common core for liveness (Cor. [42](#Thmtheorem42 "Corollary 42 (Liveness of Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), Prop. [43](#Thmtheorem43 "Proposition 43 (Leader-Liveness of Cordial Miners Asynchrony Protocol). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), dissemination, and cordiality are sufficient to ensure it. Finally, we complete the proof of liveness of the Cordial Miners protocols (Prop. [44](#Thmtheorem44 "Proposition 44 (Cordial Miners Protocol Liveness). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

This concludes the proof outline that Cordial Miners is live and safe and thus completes the proof of Theorem [13](#Thmtheorem13 "Theorem 13 (Cordial Miners Protocols Safety and Liveness). ‣ 6.3 Correctness Proof Outline ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

## 7 Performance Analysis

We analyze the performance of Cordial Miners assuming the maximum number of Byzantine miners, i.e., n\=3​f+1n=3f+1. For the good case bit complexity, we assume f∈O⁡(1)f\\in O(1) and the network is synchronous.

Latency (See Table [1](#S1.T1 "Table 1 ‣ 1 Introduction ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Latency is defined as the number of blocklace rounds between every two consecutive final leaders, i.e., the number of blocklace rounds between two instances where τ\\tau outputs new blocks. This is also equivalent to the number of communication rounds since we do not use RB to disseminate blocks. The good case latency for both models is simply the wavelength.

For the expected case, in the asynchronous instance of the protocol, each wave ww consists of 55 rounds. According to Lemma [40](#Thmtheorem40 "Lemma 40 (Blocklace Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), the probability that the leader block is final in the first round rr of ww, namely that a supermajority of the blocks in r+4r+4 each super-ratify the leader block at rr is 23\\frac{2}{3}. Therefore, in the expected case a leader block is final every 1.51.5 waves, and therefore the expected latency is 1.5​w\=7.51.5w=7.5 rounds of communication.

The adversary can equivocate or not be cordial up to ff times, but after each Byzantine process pp equivocates, all correct processes eventually detect the equivocation and do not consider pp’s blocks as part of their cordial rounds when building the blocklace. Thus, in an infinite run, equivocations do not affect the overall expected latency.

In the ES version, each wave ww consists of 33 rounds. The probability that the leader block is final is if the leader block is created by a correct miner, i.e., the probability is 23\\frac{2}{3}, i.e., same as asynchrony. Thus, in the expected case, the latency is 1.5​w\=4.51.5w=4.5 rounds.

Bit complexity. An equivocator is eventually excommunicated, and therefore eventually the number of equivocating blocks that are disseminated is limited (see Prop. [39](#Thmtheorem39 "Proposition 39 (Equivocators-Free Suffix). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Each block in the blocklace is linear in size since it has a linear number of hash pointers to previous blocks. A Byzantine miner can cause the block it creates to be sent to all miners by all the other correct miners, causing the block’s bit complexity to be O⁡(n3)O(n^{3}) per such block. Thus, in the worst case, where f∈Θ⁡(n)f\\in\\Theta(n), the asymptotic bit complexity is O⁡(n3)O(n^{3}) per block. But, since the block size is O⁡(n)O(n), we can batch O⁡(n)O(n) transactions in it without increasing its asymptotic size. Therefore, we can amortize the bit complexity by a linear factor for each transaction, causing the amortized bit complexity per transaction to be O⁡(n2)O(n^{2}) in the worst case.

For the good case in the ES version, where f∈O⁡(1)f\\in O(1) and the network is synchronous after GST, every block created by a correct miner is sent once from its creator to the other miners. Miners wait for timeout time after a round rr is cordial before they move to the next round, which ensures that all blocks sent by correct miners in round rr arrive to all other correct miners before they move to round r+1r+1. Therefore, blocks by correct miners in round r+1r+1 observe all blocks by correct miners in round rr. Thus, the Byzantine miners can cause only a constant number of blocks per round to be sent by every correct miner to every other correct miner. Therefore, the bit complexity of sending each block in the good case is O⁡(n2)O(n^{2}), and by batching O⁡(n)O(n) transaction per block, we get an amortized bit complexity of O⁡(n)O(n) per transaction.

## 8 Related Work

The use of a DAG-like structure to solve consensus has been introduced in previous works, especially in asynchronous networks. Hashgraph \[[4](#bib.bib4)\] builds an unstructured DAG, with each block containing two references to previous blocks, and on top of the DAG, the miners run an inefficient binary agreement protocol. This leads to expected exponential time complexity. Aleph  \[[20](#bib.bib20)\] builds a structured round-based DAG, where miners proceed to the next round once they receive 2​f+12f+1 DAG vertices from other miners in the same round. On top of the DAG construction protocol, a binary agreement protocol decides on the order of vertices to commit. Blockmania \[[13](#bib.bib13)\] uses a variant of PBFT \[[11](#bib.bib11)\] in the ES model and also uses reliable broadcast to disseminate blocks. Both protocols have higher latency than Cordial Miners since they use RB. GHOST \[[32](#bib.bib32)\], IOTA \[[25](#bib.bib25)\], and Avalanche \[[26](#bib.bib26)\] are DAG protocols for the permissionless model.

As mentioned in the introduction, the two state-of-the-art DAG-based protocols are DAG-Rider \[[21](#bib.bib21)\] and Bullshark \[[33](#bib.bib33)\]. DAG-Rider is a BAB protocol for the asynchronous model in which the miners jointly build a DAG of blocks, with blocks as vertices and pointers to previously created blocks as edges, divided into strong and weak edges. Strong edges are used for the commit rule, and weak edges are used to ensure fairness. Narwhal \[[14](#bib.bib14)\] is an implementation based on DAG-Rider for a relaxed networking model and works well assuming messages arrival is not bounded, but also not controlled by the adversary. Tusk \[[14](#bib.bib14)\] is a similar consensus protocol to DAG-Rider built on top of Narwhal. Bullshark \[[33](#bib.bib33)\] is a variation of DAG-Rider designed for the ES model with about half the latency of DAG-Rider. Cordial Miners outperform these protocols in terms of latency (for the same message complexity). Other DAG-based protocols include \[[12](#bib.bib12), [18](#bib.bib18)\], which are for a non-Byzantine failure model.

Another category of Byzantine consensus protocols is Leader-based. Examples include PBFT \[[11](#bib.bib11)\], Tendermint \[[8](#bib.bib8)\], HotStuff \[[34](#bib.bib34), [24](#bib.bib24)\], and VABA \[[1](#bib.bib1)\]. In these protocols, a designated leader proposes a block, sends them to the miners, and collects votes on its proposal, and a Byzantine leader can result in wasted time in which no blocks are output. Another difference is that these protocols are unbalanced in terms of the network as the leader is in charge of disseminating its block, collecting votes, and disseminating them, while the other miners only need to vote. On the other hand, DAG-based protocols like Cordial Miners are symmetric in that all miners perform exactly the same tasks.

## 9 Conclusion

We presented Cordial Miners, a family of low-latency, high-efficiency consensus protocols with instances for eventual synchrony and asynchrony. Cordial Miners achieve that by forgoing Reliable Broadcast and using the blocklace for the three major tasks of consensus – dissemination, equivocation exclusion, and ordering.

## References

-   \[1\] Ittai Abraham, Dahlia Malkhi, and Alexander Spiegelman. Asymptotically optimal validated asynchronous byzantine agreement. In Proceedings of the 2019 ACM Symposium on Principles of Distributed Computing, pages 337–346, 2019.
-   \[2\] Ittai Abraham, Kartik Nayak, Ling Ren, and Zhuolun Xiang. Good-case latency of Byzantine broadcast: A complete categorization. In Proceedings of the 2021 ACM Symposium on Principles of Distributed Computing, pages 331–341, 2021.
-   \[3\] Hagit Attiya and Jennifer Welch. Distributed computing: fundamentals, simulations, and advanced topics, volume 19. John Wiley & Sons, 2004.
-   \[4\] Leemon Baird. The swirlds Hashgraph consensus algorithm: Fair, fast, Byzantine fault tolerance. Report, Swirlds, 2016.
-   \[5\] Michael Ben-Or, Ran Canetti, and Oded Goldreich. Asynchronous secure computation. In Proceedings of the twenty-fifth annual ACM symposium on Theory of computing, pages 52–61, 1993.
-   \[6\] Dan Boneh, Ben Lynn, and Hovav Shacham. Short signatures from the weil pairing. In International conference on the theory and application of cryptology and information security, pages 514–532. Springer, 2001.
-   \[7\] Gabriel Bracha. Asynchronous Byzantine agreement protocols. Information and Computation, 75(2):130–143, 1987.
-   \[8\] Ethan Buchman. Tendermint: Byzantine fault tolerance in the age of blockchains. PhD thesis, University of Guelph, 2016.
-   \[9\] Christian Cachin, Klaus Kursawe, Frank Petzold, and Victor Shoup. Secure and efficient asynchronous broadcast protocols. In Annual International Cryptology Conference, pages 524–541. Springer, 2001.
-   \[10\] Christian Cachin, Klaus Kursawe, and Victor Shoup. Random oracles in Constantinople: Practical asynchronous byzantine agreement using cryptography. Journal of Cryptology, 18(3):219–246, 2005.
-   \[11\] Miguel Castro and Barbara Liskov. Practical Byzantine fault tolerance. In Proceedings of the Third Symposium on Operating Systems Design and Implementation, page 173–186, New Orleans, Louisiana, USA, 1999. USENIX Association.
-   \[12\] Gregory V Chockler, Nabil Huleihel, and Danny Dolev. An adaptive totally ordered multicast protocol that tolerates partitions. In Proceedings of the seventeenth annual ACM symposium on Principles of distributed computing, pages 237–246, 1998.
-   \[13\] George Danezis and David Hrycyszyn. Blockmania: from block DAGs to consensus. arXiv preprint arXiv:1809.01620, 2018.
-   \[14\] George Danezis, Lefteris Kokoris-Kogias, Alberto Sonnino, and Alexander Spiegelman. Narwhal and tusk: a dag-based mempool and efficient bft consensus. In Proceedings of the Seventeenth European Conference on Computer Systems, pages 34–50, 2022.
-   \[15\] Sourav Das, Zhuolun Xiang, and Ling Ren. Asynchronous data dissemination and its applications. In Proceedings of the 2021 ACM SIGSAC Conference on Computer and Communications Security, pages 2705–2721, 2021.
-   \[16\] Sourav Das, Zhuolun Xiang, and Ling Ren. Near-optimal balanced reliable broadcast and asynchronous verifiable information dispersal. Cryptology ePrint Archive, 2022.
-   \[17\] Danny Dolev and Eli Gafni. Some garbage in-some garbage out: Asynchronous t-byzantine as asynchronous benign t-resilient system with fixed t-trojan-horse inputs. arXiv preprint arXiv:1607.01210, 2016.
-   \[18\] Danny Dolev, Shlomo Kramer, and Dalia Malki. Early delivery totally ordered multicast in asynchronous environments. In FTCS-23 The Twenty-Third International Symposium on Fault-Tolerant Computing, pages 544–553. IEEE, 1993.
-   \[19\] Danny Dolev and Rüdiger Reischuk. Bounds on information exchange for byzantine agreement. Journal of the ACM (JACM), 32(1):191–204, 1985.
-   \[20\] Adam Gągol and Michał Świętek. Aleph: A leaderless, asynchronous, byzantine fault tolerant consensus protocol. arXiv preprint arXiv:1810.05256, 2018.
-   \[21\] Idit Keidar, Eleftherios Kokoris-Kogias, Oded Naor, and Alexander Spiegelman. All you need is dag. In Proceedings of the 2021 ACM Symposium on Principles of Distributed Computing, pages 165–175, 2021.
-   \[22\] Idit Keidar, Oded Naor, and Ehud Shapiro. Cordial miners: A family of simple, efficient and self-contained consensus protocols for every eventuality. arXiv preprint arXiv:2205.09174, 2022.
-   \[23\] Benoît Libert, Marc Joye, and Moti Yung. Born and raised distributively: Fully distributed non-interactive adaptively-secure threshold signatures with short shares. Theoretical Computer Science, 645:1–24, 2016.
-   \[24\] Dahlia Malkhi and Kartik Nayak. Hotstuff-2: Optimal two-phase responsive bft. Cryptology ePrint Archive, 2023.
-   \[25\] Serguei Popov. The tangle. [https://assets.ctfassets.net/r1dr6vzfxhev/2t4uxvsIqk0EUau6g2sw0g/45eae33637ca92f85dd9f4a3a218e1ec/iota1\_4\_3.pdf](https://assets.ctfassets.net/r1dr6vzfxhev/2t4uxvsIqk0EUau6g2sw0g/45eae33637ca92f85dd9f4a3a218e1ec/iota1_4_3.pdf), 2018.
-   \[26\] Team Rocket, Maofan Yin, Kevin Sekniqi, Robbert van Renesse, and Emin Gün Sirer. Scalable and probabilistic leaderless bft consensus through metastability. arXiv preprint arXiv:1906.08936, 2019.
-   \[27\] Maria A Schett and George Danezis. Embedding a deterministic BFT protocol in a block DAG. In Proceedings of the 2021 ACM Symposium on Principles of Distributed Computing, pages 177–186, 2021.
-   \[28\] Ehud Shapiro. Multiagent transition systems: Protocol-stack mathematics for distributed computing. arXiv preprint arXiv:2112.13650, 2021.
-   \[29\] Ehud Shapiro. Grassroots distributed systems: Concept, examples, implementation and applications. arXiv preprint arXiv:2301.04391, 2023.
-   \[30\] Robert Shostak, Marshall Pease, and Leslie Lamport. The Byzantine generals problem. ACM Transactions on Programming Languages and Systems, 4(3):382–401, 1982.
-   \[31\] Victor Shoup. Practical threshold signatures. In International Conference on the Theory and Applications of Cryptographic Techniques, pages 207–220. Springer, 2000.
-   \[32\] Yonatan Sompolinsky and Aviv Zohar. Secure high-rate transaction processing in Bitcoin. In International Conference on Financial Cryptography and Data Security, pages 507–527. Springer, 2015.
-   \[33\] Alexander Spiegelman, Neil Giridharan, Alberto Sonnino, and Lefteris Kokoris-Kogias. Bullshark: Dag bft protocols made practical. In Proceedings of the 2022 ACM SIGSAC Conference on Computer and Communications Security, pages 2705–2718, 2022.
-   \[34\] Maofan Yin, Dahlia Malkhi, Michael K Reiter, Guy Golan Gueta, and Ittai Abraham. Hotstuff: Bft consensus with linearity and responsiveness. In Proceedings of the 2019 ACM Symposium on Principles of Distributed Computing, pages 347–356, 2019.

## Appendix A Formal Model

The following is a mathematical formal definition of the cordial miners consensus protocols.

###### Definition 14 (Block, Acknowledge).

A block bb is a triple b\=(p,a,H)b=(p,a,H) signed by pp, referred to as a pp\-block, s.t. p∈Πp\\in\\Pi is the miner that creates bb, a∈𝒜a\\in\\mathcal{A} is the payload of bb, and HH is a finite set of hash pointers to blocks. Namely, for each h∈Hh\\in H, h\=hash​(b′)h=\\textit{hash}(b^{\\prime}) for some block b′b^{\\prime}. In which case we also say that bb acknowledges b′b^{\\prime}. If H\=∅H=\\emptyset then bb is initial.

###### Definition 15 (Blocklace).

Let ℬ\\mathcal{B} be the maximal set of blocks over Π\\Pi, 𝒜\\mathcal{A}, and hash for which the induced directed graph (ℬ,ℰ)(\\mathcal{B},\\mathcal{E}) is acyclic. A blocklace over 𝒜\\mathcal{A} is a set of blocks B⊆ℬB\\subseteq\\mathcal{B}.

###### Definition 16 (≻\\succ, Observe).

Given two blocks b,b′b,b^{\\prime}, the strict partial order ≻\\succ is defined by b′≻bb^{\\prime}\\succ b if there is a nonempty path from b′b^{\\prime} to bb. A block b′b^{\\prime} observes bb if b′⪰bb^{\\prime}\\succeq b. Given a blocklace BB, Miner pp observes bb in BB if there is a pp\-block b′∈Bb^{\\prime}\\in B that observes bb. A group of miners Q⊆ΠQ\\subseteq\\Pi observes bb in BB if every miner p∈Qp\\in Q observes bb.

###### Definition 17 (Equivocation, Equivocator).

A pair of pp\-blocks b≠b′∈ℬb\\neq b^{\\prime}\\in\\mathcal{B}, p∈Πp\\in\\Pi, form an equivocation by pp if they are not consistent wrt ≻\\succ, namely b′⊁bb^{\\prime}\\not\\succ b and b⊁b′b\\not\\succ b^{\\prime}. A miner pp is an equivocator in BB, equivocator​(p,B)\\textit{equivocator}(p,B), if BB has an equivocation by pp.

###### Definition 18 (Approval).

Given blocks b,b′∈ℬb,b^{\\prime}\\in\\mathcal{B}, the block bb approves b′b^{\\prime} if bb observes b′b^{\\prime} and does not observe any block b′′b^{\\prime\\prime} that together with b′b^{\\prime} forms an equivocation. A miner p∈Πp\\in\\Pi approves b′b^{\\prime} in BB if there is a pp\-block b∈Bb\\in B that approves b′b^{\\prime}. A set of miners Q⊆ΠQ\\subseteq\\Pi approve b′b^{\\prime} in BB if every miner p∈Qp\\in Q approves b′b^{\\prime} in BB.

###### Definition 19 (Closure, Closed, Tip).

The closure of b∈ℬb\\in\\mathcal{B} wrt ≻\\succ is the set \[b\]:={b′∈ℬ:b⪰b′}\[b\]:=\\{b^{\\prime}\\in\\mathcal{B}:b\\succeq b^{\\prime}\\}. The closure of B⊂ℬB\\subset\\mathcal{B} wrt ≻\\succ is the set \[B\]:=⋃b∈B\[b\]\[B\]:=\\bigcup\_{b\\in B}\[b\]. A blocklace B⊆ℬB\\subseteq\\mathcal{B} is closed if B\=\[B\]B=\[B\]. A block b∈ℬb\\in\\mathcal{B} is a tip of BB if b∉\[B∖{b}\]b\\notin\[B\\setminus\\{b\\}\].

###### Definition 20 (Block Depth/Round, Blocklace Prefix & Suffix).

The depth (or round) of a block b∈ℬb\\in\\mathcal{B}, depth​(b)\\textit{depth}(b), is the maximal length of any path of pointers emanating from bb. For a blocklace B⊆ℬB\\subseteq\\mathcal{B} and d≥0d\\geq 0, the depth-dd prefix of BB is B⁡(d):={b∈B:depth​(b)≤d}B(d):=\\{b\\in B:\\textit{depth}(b)\\leq d\\}, and the depth-dd suffix of BB is B¯​(d):=B∖B​(d)\\bar{B}(d):=B\\setminus B(d).

###### Definition 21 (Supermajority).

A set of miners P⊂ΠP\\subset\\Pi is a supermajority if |P|\>n+f2|P|>\\frac{n+f}{2}. A set of blocks BB is a supermajority if the set of miners P\={p∈Π:∃b∈B​ is a p\-block}P=\\{p\\in\\Pi:\\exists b\\in B\\text{ is a $p$-block}\\} is a supermajority.

###### Definition 22 (Ratified and Super-Ratified Block).

A block b∈ℬb\\in\\mathcal{B} is (i) ratified by a set of blocks B⊆ℬB\\subseteq\\mathcal{B}, if \[B\]\[B\] includes a supermajority of blocks that approve bb; (ii) ratified by a block bb if it is ratified by the set of blocks \[b\]\[b\]; and (iii) super-ratified by blocklace B⊂ℬB\\subset\\mathcal{B} if \[B\]\[B\] includes a supermajority of blocks, each of which ratifies bb

###### Definition 23 (Wavelength, Leader Selection Function, Leader Block).

Given a wavelength w≥1w\\geq 1, a leader selection function is a partial function l:ℕ↦Πl:\\mathbb{N}\\mapsto\\Pi satisfying (i) coverage: ∀r∈ℕ:l⁡(r)∈Π\\forall r\\in\\mathbb{N}\\colon l(r)\\in\\Pi if r​ mod ​w\=0r\\textbf{ mod }w=0 else l(r)\=⊥l(r)=\\bot and (ii) fairness: with probability 1 ∀r∈ℕ,p∈Π​∃r′\>r:l⁡(r′)\=p\\forall r\\in\\mathbb{N},p\\in\\Pi~\\exists r^{\\prime}>r:l(r^{\\prime})=p. A pp\-block bb is a leader block if l​(depth​(b))\=pl(\\textit{depth}(b))=p.

###### Definition 24 (Final Leader Block).

Let B⊆ℬB\\subseteq\\mathcal{B} be a blocklace. A leader block b∈Bb\\in B of round rr is final in BB if it is super-ratified in B⁡(r+w−1)B(r+w-1).

###### Definition 25 (Cordial Block, Blocklace).

A block b∈ℬb\\in\\mathcal{B} of round rr is cordial if r\=1r=1 or it acknowledges blocks by a supermajority of miners of round r−1r-1. A blocklace B⊂ℬB\\subset\\mathcal{B} is cordial if all its blocks are cordial.

###### Definition 26.

A pp\-block b∈ℬb\\in\\mathcal{B} in correct, if it is cordial and pp does doe equivocate in \[b\]\[b\].

###### Definition 27 (Disseminating).

Given a blocklace B⊆ℬB\\subseteq\\mathcal{B}, a set of miners P⊆ΠP\\subseteq\\Pi is mutually disseminating in BB, or disseminating for short, if for any p,q∈Pp,q\\in P and any pp\-block b∈Bb\\in B there is a qq\-block b′∈Bb^{\\prime}\\in B such that b′≻bb^{\\prime}\\succ b. The blocklace BB is disseminating if it has a disseminating supermajority.

###### Definition 28 (Shared Random Coin).

Assume some d\>0d>0 and let S\={toss\_coin​(ps,d):p∈P}S=\\{\\textit{toss\\\_coin}(p\_{s},d):p\\in P\\} for a set of miners P⊆ΠP\\subseteq\\Pi, |P|\>f+1|P|>f+1. For the shared random coin, the function combine\_tosses has the following properties:

Agreement

If both S′,S′′⊆SS^{\\prime},S^{\\prime\\prime}\\subseteq S and both |S′|,|S′′|\>f+1|S^{\\prime}|,|S^{\\prime\\prime}|>f+1, then  
combine\_tosses​(S′,d)\=combine\_tosses​(S′′,d)\\textit{combine\\\_tosses}(S^{\\prime},d)=\\textit{combine\\\_tosses}(S^{\\prime\\prime},d)

Termination

combine\_tosses​(S,d)∈Π\\textit{combine\\\_tosses}(S,d)\\in\\Pi.

Fairness

The coin is fair, i.e., for every set SS computed as above and any p∈Πp\\in\\Pi, the probability that p\=combine\_tosses​(S,d)p=\\textit{combine\\\_tosses}(S,d) is 1n\\frac{1}{n}.

Unpredictability

If S′⊂SS^{\\prime}\\subset S, |S′|<f+1|S^{\\prime}|<f+1, then the probability that the adversary can use S′S^{\\prime} to guess the value of combine\_tosses​(S,d)\\textit{combine\\\_tosses}(S,d) is less than 1n+ϵ\\frac{1}{n}+\\epsilon.

###### Definition 29 (Equivocator-Repelling).

Let b∈ℬb\\in\\mathcal{B} be a pp\-block, p∈Πp\\in\\Pi, that acknowledges a set of blocks B⊂ℬB\\subset\\mathcal{B}. Then bb is equivocator-repelling if pp does not equivocate in \[b\]\[b\] and all blocks in BB are equivocator-repelling. A blocklace BB is equivocator-repelling if every block b∈Bb\\in B is equivocator-repelling.

## Appendix B Figures

![Refer to caption](2205.09174v6/Figs/finality.png)

Figure 2: Finality of a Super-Ratified Leader (Definition [24](#Thmtheorem24 "Definition 24 (Final Leader Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")): Assume that a leader block (blue dot) is super-ratified. A ratifying supermajority is represented by a thick red line, each member of which observes a possibly different approving supermajority represented by a green thick line. We show that the blue leader is ratified by any subsequent cordial leader. (A) The successive cordial leader (purple dot) is one round following the ratifying supermajority. Being cordial, it observes a supermajority (thick purple line) that must have an intersection (black dot) with the ratifying supermajority, hence it observes an approving supermajority and thus ratifies the blue leader. (B) A successive leader is more than one round following the ratifying supermajority. Being cordial, it observes a supermajority (thick purple line). There must be a correct miner common to the purple and red supermajority, with blocks in both (black dots); being a correct miner, its later block observes the earlier block (black line). Hence the purple leader observes the approving supermajority (via black lines) and hence ratifies the blue leader.

![Refer to caption](2205.09174v6/Figs/liveness-condition.jpeg)

Figure 3: Liveness Condition, Proposition [5](#Thmtheorem5 "Proposition 5 (Blocklace Leader Liveness Condition). ‣ 4.3 Blocklace Liveness ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

![Refer to caption](2205.09174v6/Figs/tau.jpeg)

Figure 4: The Operation of τ\\tau, Safety and Liveness: (A) *The Input of τ\\tau*: A blocklace with final leaders (large dots) and leaders ratified by their successors (small dots). Each leader observes the portion of the blocklace below it (including the lines emanating from it). (B) *The Output of τ\\tau*: A sequence of blocks consisting of fragments. The sequence of fragments is computed recursively backward, starting from the last final leader, and back from each leader to the previous leader it ratifies. The input to computing the fragment consists of the portion of the blocklace observed by the current leader but not observed by the previous ratified leader. The output from each fragment is a sequence of blocks computed forward by topological sort of the input blocklace fragment, respecting ≻\\succ and using the leader of the fragment to resolve and exclude equivocations. Final leaders are final, hence the backward computation starting from the last purple final leader need not proceed beyond the recursive call to the previous red final leader, as the output sequence up to the previous final leader has already been computed by the previous invocation of τ\\tau. Safety Requirement: A final leader (large dot) is ratified by any subsequent leader (large or small dot). Liveness Requirement: Any leader will eventually have a subsequent final leader (large dot) with probability 1. (C) *Leader-Based Equivocation Exclusion*: The green fragment created by the green leader includes the VV\-marked red block, since the green leader does not observe the red equivocation. However, the red XX\-marked red block is excluded from the purple fragment created by the purple leader, since the purple leader observes the equivocation among the two red blocks.

![Refer to caption](2205.09174v6/Figs/core.jpeg)

Figure 5: Common Core, Ratified Common Core, Safety and Liveness of Decision Rule for Asynchrony: (A) *Proof of Lemma [40](#Thmtheorem40 "Lemma 40 (Blocklace Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") and Corollary [41](#Thmtheorem41 "Corollary 41 (Super-Ratified Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")*: Rounds rr to r+3r+3 relate to the proof of Lemma [40](#Thmtheorem40 "Lemma 40 (Blocklace Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), where the existence of a common core at round rr is established. Round r+4r+4 relates to Corollary [41](#Thmtheorem41 "Corollary 41 (Super-Ratified Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), which establishes that all cordial blocks at round r+4r+4 ratify all members of the common core of round rr via a supermajority at round r+3r+3. (B) *The common-core table TT* used in the proof to relate rounds r+1r+1 and r+2r+2. (C) *The decision rule for asynchrony*: Protocol wavelength is 5. Liveness: Common-core ensures that the blue leader at round rr is super-ratified by a red supermajority at round r+4r+4 with probability 2​f+13​f+1\\frac{2f+1}{3f+1}, thus ensuring liveness and expected latency of 7.5 rounds. Safety: A blue leader is approved by every cordial block at round r+3r+3 (green) and hence is ratified by every cordial block at round r+4r+4 (red) and beyond.

## Appendix C Proofs

In this section, we provide the full proofs deferred from the paper.

See [3](#Thmtheorem3 "Proposition 3. ‣ 4.2 Blocklace Safety ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

###### Proof of Proposition [3](#Thmtheorem3 "Proposition 3. ‣ 4.2 Blocklace Safety ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Let BB be a cordial blocklace and b∈Bb\\in B (blue dot in Fig. [2](#A2.F2 "Figure 2 ‣ Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) a final leader block of round rr in BB. We have to show bb is ratified by any subsequent leader block in BB. We consider Definition [24](#Thmtheorem24 "Definition 24 (Final Leader Block). ‣ Appendix A Formal Model ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), and in reference to the two cases in Fig. [2](#A2.F2 "Figure 2 ‣ Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"). Consider a leader block bb of round rr (black dot) and a leader block b′b^{\\prime} (purple dot) of a round r′\>r+wr^{\\prime}>r+w. There are two cases:

1.  A.
    
    There is an overlap between the supermajority observed by b′b^{\\prime} at round r′−1r^{\\prime}-1 (thick purple line) and the supermajority that ratifies bb (thick red line). Then there is a block b′′b^{\\prime\\prime} (black dot) shared by both, hence b′b^{\\prime} observes b′′b^{\\prime\\prime}, which observes a supermajority (thick green line) that approves bb, hence b′b^{\\prime} ratifies bb.
    
2.  B.
    
    The supermajority observed by b′b^{\\prime} at round r′−1r^{\\prime}-1 (thick purple line) is of a later round than the members of the supermajority that ratifies bb (thick red line). By counting, there is a non-equivocating miner p∈P​ip\\in Pi with a block b1b\_{1} in the purple supermajority and a block b2b\_{2} in the red supermajority (black dots). Since pp is non-equivocating, b1b\_{1} observes b2b\_{2}. Hence, b′b^{\\prime} observes b1b\_{1}, which observes b2b\_{2}, which observes the green supermajority that approves bb, hence b′b^{\\prime} ratifies bb.
    

This completes the proof. ∎

See [5](#Thmtheorem5 "Proposition 5 (Blocklace Leader Liveness Condition). ‣ 4.3 Blocklace Liveness ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

###### Proof of Proposition [5](#Thmtheorem5 "Proposition 5 (Blocklace Leader Liveness Condition). ‣ 4.3 Blocklace Liveness ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Let B⊂ℬB\\subset\\mathcal{B} be a cordial blocklace and P⊆ΠP\\subseteq\\Pi a supermajority of miners non-equivocating and disseminating in BB. Let bb be a pp\-block by a miner p∈Pp\\in P (blue dot in Fig. [3](#A2.F3 "Figure 3 ‣ Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). As PP are disseminating in BB, then for every q∈Pq\\in P there is a first qq\-block bq∈Pb\_{q}\\in P that observes bb; let rr be the maximal round of any of these blocks (thick horizontal red line). By assumption, BB has a final leader block b^\\hat{b} of round r^\>r\\hat{r}>r (purple dot). As b^\\hat{b} is cordial, it must observe a block bq′b^{\\prime}\_{q} of depth r^−1\\hat{r}-1 of a miner q∈Pq\\in P (black dot). As qq is non-equivocating, there is a (possibly empty) path from bq′b^{\\prime}\_{q} to bqb\_{q} (black path among black dots), and from there to bb (blue line). Hence b^\\hat{b} observes bb. ∎

###### Observation 30 (Approving an Equivocation).

If miner p∈Πp\\in\\Pi approves an equivocation b1,b2b\_{1},b\_{2} in a blocklace B⊆ℬB\\subseteq\\mathcal{B}, then pp is an equivocator in BB.

###### Proof of Observation [30](#Thmtheorem30 "Observation 30 (Approving an Equivocation). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

By way of contradiction, assume that pp approves an equivocation b1,b2∈Bb\_{1},b\_{2}\\in B via two blocks, b3b\_{3} and b4b\_{4} in BB, respectively, that do not constitute an equivocation. So w.l.o.g. assume that b3b\_{3} observes b4b\_{4}. However, since b4b\_{4} observes b2b\_{2}, then b3b\_{3} also observes b2b\_{2}, and hence does not approve b1b\_{1}. A contradiction. ∎

###### Lemma 31 (No Supermajority Approval for Equivocation).

For every two equivocating blocks in a blocklace, at most one can have a supermajority approval.

###### Proof of Lemma [31](#Thmtheorem31 "Lemma 31 (No Supermajority Approval for Equivocation). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Assume that b1,b2b\_{1},b\_{2} are equivocating blocks, and that there are two supermajorities Q1,Q2⊆PQ\_{1},Q\_{2}\\subseteq P, where Q1Q\_{1} approves b1b\_{1} and Q2Q\_{2} approves b2b\_{2}. A counting argument shows that two supermajorities must have in common at least one correct miner. Let p∈Q1∩Q2p\\in Q\_{1}\\cap Q\_{2} be such a correct miner. Since p∈Q1p\\in Q\_{1} it approves b1b\_{1} and since p∈Q2p\\in Q\_{2} it approves b2b\_{2} by construction. Observation [30](#Thmtheorem30 "Observation 30 (Approving an Equivocation). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") shows that an miner that approves an equivocation must be a an equivocator, hence pp is an equivocator. A contradiction. ∎

###### Observation 32 (Dissemination is Unbounded).

If a set of miners P⊆ΠP\\subseteq\\Pi, |P|\>1|P|>1, are disseminating in a blocklace BB that includes a pp\-block, p∈Pp\\in P, then BB is infinite and any suffix of BB has blocks by every member of PP.

###### Proof.

Under the assumptions of the observation, every correct miner qq will receive bb and create qq\-block observing bb. BB cannot be finite since any ‘last’ block by a correct miner must be followed by blocks by all correct miners, so it can’t be last. And for the same reason any suffix has blocks by all correct miners. ∎

See [9](#Thmtheorem9 "Proposition 9 (Monotonicity of 𝜏). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

###### Proof of Proposition [9](#Thmtheorem9 "Proposition 9 (Monotonicity of 𝜏). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Let B,B1,B2B,B\_{1},B\_{2} be blocklaces as assumed by the Proposition. If B2B\_{2} has no final leader then τ⁡(B2)\\tau(B\_{2}) is the empty sequence and the proposition holds vacuously. Let b^2\\hat{b}\_{2} be the last final leader of B2B\_{2} and b^1\\hat{b}\_{1} be the last final leader of B1B\_{1}. Note that according to Definition[6](#Thmtheorem6 "Definition 6 (𝜏). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), τ⁡(B1)\\tau(B\_{1}) calls τ′​(b^1)\\tau^{\\prime}(\\hat{b}\_{1}) and τ⁡(B2)\\tau(B\_{2}) calls τ′​(b^2)\\tau^{\\prime}(\\hat{b}\_{2}). Let b1,b2​…,bkb\_{1},b\_{2}\\ldots,b\_{k}, k≥2k\\geq 2, be the sequence of ratified leaders in the recursive calls of the execution of τ′​(b^1)\\tau^{\\prime}(\\hat{b}\_{1}), starting with b1\=b^1b\_{1}=\\hat{b}\_{1}. We argue that b^2\\hat{b}\_{2} is called in this execution, namely b^2\=bj\\hat{b}\_{2}=b\_{j} for some j∈\[k\]j\\in\[k\]. Note that according to Proposition [3](#Thmtheorem3 "Proposition 3. ‣ 4.2 Blocklace Safety ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), b^1\=b1\\hat{b}\_{1}=b\_{1}, being cordial, ratifies b^2\\hat{b}\_{2}. Let j∈\[k\]j\\in\[k\] be the last index for which bjb\_{j} ratifies b^2\\hat{b}\_{2}. We argue by way of contradiction that bj+1\=b^2b\_{j+1}=\\hat{b}\_{2}. Consider three cases regarding the relative depths of bj+1b\_{j+1} and b^2\\hat{b}\_{2}:

-   \=
    
    Note that two different blocks of the same depth cannot observe each other: If only one observes the other, it is one deeper than the other; if both observe each other they form a cycle, which is impossible. Since both bj+1b\_{j+1} and b^2\\hat{b}\_{2} are leader blocks of the same depth, then they must be by the same leader, and hence, being different blocks by the same miner that do not observe each other, they form an equivocation. By assumption, both are ratified, implying that both have supermajority approval, contradicting the assumption that there is a supermajority of correct miners in BB.
    
-   ¿
    
    If bj+1b\_{j+1} is deeper than b^2\\hat{b}\_{2}, then by Definition [6](#Thmtheorem6 "Definition 6 (𝜏). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), τ′\\tau^{\\prime} elects the first leader ratified by the current leader bjb\_{j}, and hence cannot prefer calling bj+1b\_{j+1} over b^2\\hat{b}\_{2}, which precedes it by assumption.
    
-   ¡
    
    If b^2\\hat{b}\_{2} is deeper, then Proposition [3](#Thmtheorem3 "Proposition 3. ‣ 4.2 Blocklace Safety ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") implies that bj+1b\_{j+1} ratifies b^2\\hat{b}\_{2}, in contradiction to the assumption that bjb\_{j} is the last leader in the list that ratifies b^2\\hat{b}\_{2}.
    

Hence b^2\\hat{b}\_{2} is included in the recursive calls of τ′​(b^1)\\tau^{\\prime}(\\hat{b}\_{1}), which, according to Definition [6](#Thmtheorem6 "Definition 6 (𝜏). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") of τ\\tau, implies that τ⁡(B2)⪯τ⁡(B1)\\tau(B\_{2})\\preceq\\tau(B\_{1}). ∎

###### Observation 33 (Consistent triplet).

Given three sequences x,x′,x′′x,x^{\\prime},x^{\\prime\\prime}, if both x′⪯xx^{\\prime}\\preceq x and x′′⪯xx^{\\prime\\prime}\\preceq x then x′x^{\\prime} and x′′x^{\\prime\\prime} are consistent.

###### Proof of Observation [33](#Thmtheorem33 "Observation 33 (Consistent triplet). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Let |x′|\=k′|x^{\\prime}|=k^{\\prime} and |x′′|\=k′′|x^{\\prime\\prime}|=k^{\\prime\\prime}. By assumption, x′x^{\\prime} consists of the first k′k^{\\prime} elements of xx and x′′x^{\\prime\\prime} consists of the first k′′k^{\\prime\\prime} elements of xx. Wlog assume k′≤k′′k^{\\prime}\\leq k^{\\prime\\prime}. Then x′x^{\\prime} consists of the first k′k^{\\prime} elements of x′′x^{\\prime\\prime}, and hence x′⪯x′′x^{\\prime}\\preceq x^{\\prime\\prime}. ∎

See [10](#Thmtheorem10 "Proposition 10 (𝜏 Safety). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

###### Proof of Proposition [10](#Thmtheorem10 "Proposition 10 (𝜏 Safety). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

By monotonicity of τ\\tau (Prop. [9](#Thmtheorem9 "Proposition 9 (Monotonicity of 𝜏). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), both τ⁡(B1)⪯τ⁡(B1∪B2)\\tau(B\_{1})\\preceq\\tau(B\_{1}\\cup B\_{2}) and τ⁡(B2)⪯τ⁡(B1∪B2)\\tau(B\_{2})\\ \\preceq\\tau(B\_{1}\\cup B\_{2}). By Observation [33](#Thmtheorem33 "Observation 33 (Consistent triplet). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), τ⁡(B1)\\tau(B\_{1}) and τ⁡(B2)\\tau(B\_{2}) are consistent. ∎

See [11](#Thmtheorem11 "Observation 11 (𝜏 output). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

###### Proof of Observation [11](#Thmtheorem11 "Observation 11 (𝜏 output). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Since bb is observed by a final leader in BB, it is also observed by the last final leader of BB. Consider the recursive construction of τ⁡(B)\\tau(B). If in its last recursive call τ′​(b′)\\tau^{\\prime}(b^{\\prime}), b′b^{\\prime} observes bb, then by definition of τ\\tau, b∈τ⁡(b′)b\\in\\tau(b^{\\prime}) and hence b∈τ⁡(B)b\\in\\tau(B). Otherwise, consider the first recursive call τ′​(b′)\\tau^{\\prime}(b^{\\prime}) by τ′​(b′′)\\tau^{\\prime}(b^{\\prime\\prime}) in which b′′b^{\\prime\\prime} observes bb but b′b^{\\prime} does not observe bb. Then by definition of τ′\\tau^{\\prime}, b∈τ′​(b′′)b\\in\\tau^{\\prime}(b^{\\prime\\prime}) and hence b∈τ⁡(B)b\\in\\tau(B). ∎

See [12](#Thmtheorem12 "Proposition 12 (𝜏 Liveness). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

###### Proof of Proposition [12](#Thmtheorem12 "Proposition 12 (𝜏 Liveness). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Let BB be as assumed and b∈Bb\\in B. As BB is leader-live, there is a final leader block b′b^{\\prime} that observes bb. Let i≥1i\\geq 1 be an index for which BiB\_{i} includes b′b^{\\prime}. Consider the call τ⁡(Bi)\\tau(B\_{i}). Since bb is a final leader in BiB\_{i}, then according to Observation [11](#Thmtheorem11 "Observation 11 (𝜏 output). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), the output of τ⁡(Bi)\\tau(B\_{i}) includes bb. ∎

See [8](#Thmtheorem8 "Theorem 8 (Sufficient Condition for the Safety and Liveness of a Blocklace-Based Ordering Consensus Protocol). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

###### Proof of Theorem [8](#Thmtheorem8 "Theorem 8 (Sufficient Condition for the Safety and Liveness of a Blocklace-Based Ordering Consensus Protocol). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Let P⊆ΠP\\subseteq\\Pi be the correct miners in a run of the protocol that produce in the limit the blocklace BB. The protocol is safe since the local blocklaces of any two miners in p,q∈Pp,q\\in P at any time are subsets of BB, hence by Proposition [10](#Thmtheorem10 "Proposition 10 (𝜏 Safety). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") the outputs of pp and qq are consistent. The protocol is live since by Proposition [12](#Thmtheorem12 "Proposition 12 (𝜏 Liveness). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), every block b∈Bb\\in B will be output by every correct miner p∈Pp\\in P. ∎

See [13](#Thmtheorem13 "Theorem 13 (Cordial Miners Protocols Safety and Liveness). ‣ 6.3 Correctness Proof Outline ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")

###### Proof Outline of Theorem [13](#Thmtheorem13 "Theorem 13 (Cordial Miners Protocols Safety and Liveness). ‣ 6.3 Correctness Proof Outline ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

We prove two propositions that together establish the Theorem: Proposition [37](#Thmtheorem37 "Proposition 37 (Cordial Miners Protocol Safety). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") shows that the two Cordial Miners protocols are safe and Proposition [44](#Thmtheorem44 "Proposition 44 (Cordial Miners Protocol Liveness). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") shows that they are live. ∎

###### Proposition 34 (Miner Asynchrony).

If a miner can create a block (Line [65](#algx3.l65 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) then it can create it also after receiving blocks from other miners.

###### Proof of Proposition [34](#Thmtheorem34 "Proposition 34 (Miner Asynchrony). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Examination of the completed\_round procedures of Alg. [4](#alg4 "Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), which gate block creation in Alg. [3](#alg3 "Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), Line [65](#algx3.l65 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), shows that if it holds for a blocklace it holds after blocks by other miners are received and buffered or added to the local blocklace. ∎

###### Proposition 35 (Miners Liveness).

In a fair run of a Cordial Miners protocol with correct miners P⊆ΠP\\subseteq\\Pi, if there is a configuration for which completed\_round​()≥d\\textit{completed\\\_round}()\\geq d (Line [63](#algx3.l63 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) for d≥0d\\geq 0 and for the blocklace of every miner p∈Pp\\in P, then there is a subsequent configuration for which completed\_round​()≥d+1\\textit{completed\\\_round}()\\geq d+1 for the blocklace of every miner p∈Pp\\in P.

###### Proof of Proposition [35](#Thmtheorem35 "Proposition 35 (Miners Liveness). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

We show by induction on the round number. Consider a configuration cc in which the depth of the last completed round in the blocklace of all miners be d≥0d\\geq 0. If d\=0d=0 then the *completed\_round*()() call (Line [63](#algx3.l63 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) returns 00 and pp can create an initial block (Line [65](#algx3.l65 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) with no predecessors (Line [11](#algx1.l11 "In Algorithm 1 ‣ 4.1 Blocklace Basics ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Assume d\>0d>0. Consider a miner p∈Pp\\in P that has not yet created a block of depth d+1d+1 in cc. Then the condition ​c​o​m​p​l​e​t​e​d​\_​r​o​u​n​d​()≥r\\emph{completed\\\_round}()\\geq r (Line [63](#algx3.l63 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) holds for r\=dr=d, and the transition to create the next block is enabled. By miner asynchrony (Proposition [34](#Thmtheorem34 "Proposition 34 (Miner Asynchrony). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), such a transition is enabled indefinitely, and by the fairness assumption, it is eventually taken, in which pp sends a new pp\-block bb of depth d+1d+1 to all other miners (Line [68](#algx3.l68 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), and includes, for each miner qq, all the blocks in the closure of bb that qq might not know of, based on the communication history of pp with qq. By assumption, all said messages among correct miners eventually arrive at their destination. Hence there is some subsequent configuration c′c^{\\prime} in which every correct miner receives a d+1d+1\-depth qq\-block bb from every other correct miner qq, as well as all preceding blocks to bb. Hence in c′c^{\\prime}, ​c​o​m​p​l​e​t​e​d​\_​r​o​u​n​d​()≥r\\emph{completed\\\_round}()\\geq r holds for r\=d+1r=d+1 for every correct miner. ∎

###### Proposition 36 (Cordial Miners Dissemination).

In a run ρ\\rho of a Cordial Miners protocol with correct miners P⊆ΠP\\subseteq\\Pi, B​(ρ)\=Bp​(ρ)B(\\rho)=B\_{p}(\\rho) for every p∈Pp\\in P.

###### Proof of Proposition [36](#Thmtheorem36 "Proposition 36 (Cordial Miners Dissemination). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Given a run ρ\\rho of a Cordial Miners protocol with correct miners P⊂ΠP\\subset\\Pi, we have to show that for any p,q∈Pp,q\\in P, a configuration cc of the run, and a block bb in the blocklace of pp is configuration cc, there is a subsequent configuration c′c^{\\prime} of the run in which bb is in the local blocklace of qq. By miners liveness (Proposition [35](#Thmtheorem35 "Proposition 35 (Miners Liveness). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), for any miner qq, there is a subsequent configuration by which miner pp sends a block to miner qq. According to the Cordial Dissemination clause (Line [68](#algx3.l68 "In Algorithm 3 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), when pp sends to qq a pp\-block of round ≥depth​(b)+1\\geq\\textit{depth}(b)+1 pp\-block, it will also send to qq all blocks that bb depends upon, minus any blocks known to qq according to the most recent qq\-block received by pp. Hence there is a subsequent configuration to c′c^{\\prime} in which bb is included in the blocklace of qq. ∎

###### Proposition 37 (Cordial Miners Protocol Safety).

The Cordial Miners protocols for asynchrony and eventual synchrony are safe.

###### Proof of Proposition [37](#Thmtheorem37 "Proposition 37 (Cordial Miners Protocol Safety). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

According to Proposition [36](#Thmtheorem36 "Proposition 36 (Cordial Miners Dissemination). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), in any computation of a Cordial Miners protocol, the local blocklace of any two correct miners p,q∈Πp,q\\in\\Pi is the same blocklace BB. Hence, in any configuration of the computation, the local blocklaces of pp and qq are subsets of BB, and hence according to Proposition [10](#Thmtheorem10 "Proposition 10 (𝜏 Safety). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), their outputs at that configuration are consistent, which is the safety requirement of ordering consensus protocols (Def. [1](#Thmtheorem1 "Definition 1 (Safety and Liveness of an Ordering Consensus Protocol). ‣ 2 Model and Problem Definition ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Hence the Cordial Miners protocols are safe. ∎

###### Proposition 38 (Leader-Liveness of Cordial Miners Eventual Synchrony Protocol).

The blocklace produced by a run of a Cordial Miners eventual synchrony protocol is leader-live with probability 1, if timeout\>Δ\\textit{timeout}>\\Delta.

###### Proof of Proposition [38](#Thmtheorem38 "Proposition 38 (Leader-Liveness of Cordial Miners Eventual Synchrony Protocol). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Let BB be the cordial blocklace produced by a run of a Cordial Miners eventual synchrony protocol, P⊆ΠP\\subseteq\\Pi the supermajority of miners correct in the run, and let r\>0r>0 be any round for which the r−1r-1 suffix of BB, B¯​(r−1)\\bar{B}(r-1), is equivocation-free, r​ mod ​w\=0r\\text{ mod }w=0, where w\=3w=3 (Line [77](#algx5.l77 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")).

Let r′\>rr^{\\prime}>r be any round following network synchronization (GST) where rmodw\=0r\\bmod w=0, and assume the honest miners are in r′r^{\\prime}. Since leader selection is pseudorandom (Line [87](#algx5.l87 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), and PP is a supermajority, there is a probability of |P|n\\frac{|P|}{n} that the r′r^{\\prime}\-leader qq is correct, namely q∈Pq\\in P. Let tt be the first time in which the blocklace of round r′r^{\\prime} at some honest miner pp is cordial. Honest miners wait until the condition for block finality is achieved before proceeding to the next round, or for a timeout, which is the estimation of the network delay Δ\\Delta (Line [78](#algx5.l78 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). By the model, we assume this estimation is accurate after GST. Since the blocks sent by honest miners arrive within Δ\\Delta, by t+Δt+\\Delta, pp receives the blocks of all honest miners in r′r^{\\prime}, including qq. Then, for every p∈Pp\\in P, the r′r^{\\prime}\-depth qq\-block bb is approved by the r′+1r^{\\prime}+1 pp\-block and super-ratified by the r′+2r^{\\prime}+2\-round block of pp. Hence, the blocks of the correct miners PP satisfy the conditions of bb being a final leader. As this holds also for the leader of any round following rr, the probability that for any depth r′≥rr^{\\prime}\\geq r, a leader in B¯​(r′)\\bar{B}(r^{\\prime}) has a final leader is 1, hence BB is leader-live with probability 1. Hence the condition of Proposition [5](#Thmtheorem5 "Proposition 5 (Blocklace Leader Liveness Condition). ‣ 4.3 Blocklace Liveness ‣ 4 The Blocklace ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), that for every r\>0r>0, BB has a final leader block of some round r′\>rr^{\\prime}>r with probability 1, is satisfied and we conclude that BB is leader-live with probability 1. ∎

###### Proposition 39 (Equivocators-Free Suffix).

Let BB be an equivocator-repelling and cordial blocklace and P⊂ΠP\\subset\\Pi the set of miners that do not equivocate in BB and are disseminating in BB. If PP is a supermajority then there is a depth d\>0d>0 for which the depth-dd suffix of BB, B¯​(d)\\bar{B}(d), includes only PP\-blocks.

###### Proof of Proposition [39](#Thmtheorem39 "Proposition 39 (Equivocators-Free Suffix). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Consider a miner q∈Πq\\in\\Pi equivocating in BB. Since BB is disseminating, there is some dd\-suffix of BB in which all blocks observe these equivocating blocks. Let B′B^{\\prime} be the d+1d+1\-suffix of BB, so that every block point to some block that observes the equivocation by qq. We claim that B′B^{\\prime} cannot include any qq block. Assume by way of contradiction that b′∈B′b^{\\prime}\\in B^{\\prime} is a qq\-block. Since BB is cordial, b′b^{\\prime} points to some block by a correct miner, which by assumption observes the equivocation by pp. Since BB is equivocation-repellent, b′∉Bb^{\\prime}\\notin B. A contradiction. If we take the maximal such dd over all equivocators, then this dd\-suffix does not include blocks by any equivocator, namely it includes only PP\-blocks. ∎

###### Lemma 40 (Blocklace Common Core).

Let BB be a cordial blocklace, P⊂ΠP\\subset\\Pi the set of miners that do not equivocate in BB and are disseminating in BB, and r\>0r>0 a depth for which the depth-(r−1)(r-1) suffix of BB, B¯​(r−1)\\bar{B}(r-1), includes only PP\-blocks (rr exists by Proposition [39](#Thmtheorem39 "Proposition 39 (Equivocators-Free Suffix). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), and hence equivocation free. If PP is a supermajority then there is a supermajority, of rr\-round blocks B^⊂B\\hat{B}\\subset B, referred to as common core, s.t. every (r+3)(r+3)\-round block approves all blocks in B^\\hat{B}.

###### Proof of Lemma [40](#Thmtheorem40 "Lemma 40 (Blocklace Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Let BB and rr be as assumed by the Lemma, and let PP be the set of miners that have (r+2)(r+2)\-round blocks in BB. Since BB is cordial and disseminating it is infinite of depth \>r+3\>r+3 (Observation [32](#Thmtheorem32 "Observation 32 (Dissemination is Unbounded). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")), it follows that |P|≥2​f+1|P|\\geq 2f+1. Define a table TT with rows and columns indexed by PP. Each (r+2)(r+2)\-round pp\-block of a miner p∈Pp\\in P observes (r+1)(r+1)\-round blocks by at least 2​f+12f+1 miners, which includes at least blocks by f+1f+1 miners of PP, represented in TT. For p,q∈Pp,q\\in P, entry T⁡\[p,q\]T\[p,q\] in the table is 11 if the (r+2)(r+2)\-round pp\-block observes the (r+1)(r+1)\-round qq\-block, and 00 otherwise. Observe that if 11 appears in entry T⁡\[p,q\]T\[p,q\], the (r+2)(r+2)\-round pp\-block observes all the 2​f+12f+1 rr\-round blocks observed by the (r+1)(r+1)\-round block of qq.

Since all miners in PP have (r+2)(r+2)\-round blocks, TT contains at least (2​f+1)​(f+1)(2f+1)(f+1) entries with 11. This implies that there is a miner in PP, say p¯\\bar{p}, that appears in at least f+1f+1 rows; let P¯\\bar{P} be the set of miners indexing p¯\\bar{p} rows and b¯\\bar{b} (blue dot in Fig. [5](#A2.F5 "Figure 5 ‣ Appendix B Figures ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) the (r+1)(r+1)\-round p¯\\bar{p}\-block. Thus, the (r+2)(r+2)\-round blocks of miners in P¯\\bar{P} (thick green line at round r+2r+2) observe b¯\\bar{b}. We argue that \[b¯\]\[\\bar{b}\] is a common core. First, note that as b¯\\bar{b} is cordial, \[b¯\]\[\\bar{b}\] includes 2​f+12f+1 rr\-round blocks. Second, consider any (r+3)(r+3)\-round block bb (green dot). It observes 2​f+12f+1 (r+2)(r+2)\-round blocks (thick red line), so it also observes at least one of the (r+1)(r+1)\-round blocks (black dot) of the f+1f+1 miners of P¯\\bar{P}, which in turn observes b¯\\bar{b}. Thus \[b¯\]⊆\[b\]\[\\bar{b}\]\\subseteq\[b\], with \[b¯\]\[\\bar{b}\], satisfying the requirements of a common core. ∎

###### Corollary 41 (Super-Ratified Common Core).

Under the same conditions as Lemma [40](#Thmtheorem40 "Lemma 40 (Blocklace Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") and assuming B^\\hat{B} is a common core, then every (r+4)(r+4)\-round block in BB ratifies every block in B^\\hat{B}, Hence every member of the common core B^\\hat{B}, is super-ratified in B⁡(r+4)B(r+4).

###### Proof of Corollary [41](#Thmtheorem41 "Corollary 41 (Super-Ratified Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Under the assumptions of the Corollary, let B^\\hat{B} be a common core and consider any (r+4)(r+4)\-block b∈Bb\\in B (purple dot). Being cordial, bb observes 2​f+12f+1 (r+2)(r+2)\-round blocks (thick purple line). By Lemma [40](#Thmtheorem40 "Lemma 40 (Blocklace Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), each of these blocks observes each block in B^\\hat{B}. Hence bb ratifies every block in B^\\hat{B}. ∎

###### Corollary 42 (Liveness of Common Core).

Let BB be a disseminating and cordial blocklace. Then there is a d\>0d>0 for which the common core (Lemma [40](#Thmtheorem40 "Lemma 40 (Blocklace Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")) holds for BB and for any round r≥dr\\geq d.

###### Proof of Corollary [42](#Thmtheorem42 "Corollary 42 (Liveness of Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

According to Proposition [39](#Thmtheorem39 "Proposition 39 (Equivocators-Free Suffix). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), BB has an equivocation-free suffix B′B^{\\prime}, to which Lemma [40](#Thmtheorem40 "Lemma 40 (Blocklace Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") applies. ∎

###### Proposition 43 (Leader-Liveness of Cordial Miners Asynchrony Protocol).

The blocklace produced by a run of a Cordial Miners asynchrony protocol is leader-live with probability 1.

###### Proof of Proposition [43](#Thmtheorem43 "Proposition 43 (Leader-Liveness of Cordial Miners Asynchrony Protocol). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

Let BB be the cordial blocklace produced by a run of a Cordial Miners asynchrony protocol, P⊆ΠP\\subseteq\\Pi the supermajority of miners correct in the run, and let r\>0r>0 be any round for which the r−1r-1 suffix of BB, B¯​(r−1)\\bar{B}(r-1), is equivocation-free, r​ mod ​w\=0r\\text{ mod }w=0, where w\=5w=5 (Line [69](#algx4.l69 "In Algorithm 4 ‣ 6 The Cordial Miners Protocols ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). According to Corollary [41](#Thmtheorem41 "Corollary 41 (Super-Ratified Common Core). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), a supermajority B^\\hat{B} of the round-rr blocks is super-ratified by all round-r+4r+4 blocks. As the leader of round rr is selected at random, and retrospectively after the common core B^\\hat{B} has been established, the probability that the elected leader is super-ratified, and hence final, is at least |P|n\\frac{|P|}{n}. As this holds also for the leader of any round following rr, the probability that for any depth d≥rd\\geq r, a leader in B¯​(d)\\bar{B}(d) has a final leader is 1, hence BB is leader-live with probability 1. ∎

###### Proposition 44 (Cordial Miners Protocol Liveness).

The Cordial Miners protocols for asynchrony and eventual synchrony are live.

###### Proof of Proposition [44](#Thmtheorem44 "Proposition 44 (Cordial Miners Protocol Liveness). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality").

According to Propositions [38](#Thmtheorem38 "Proposition 38 (Leader-Liveness of Cordial Miners Eventual Synchrony Protocol). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality") and [43](#Thmtheorem43 "Proposition 43 (Leader-Liveness of Cordial Miners Asynchrony Protocol). ‣ Appendix C Proofs ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), the blocklace produced in any computation of the Cordial Miners protocols for eventual synchrony and asynchrony is leader-live with probability 1. According to Proposition [12](#Thmtheorem12 "Proposition 12 (𝜏 Liveness). ‣ 5 Blocklace Ordering with 𝜏 ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality"), if the function τ\\tau is applied to a sequence of blocklaces that converge to a leader-live blocklace BB then any b∈Bb\\in B appears eventually in the output of τ\\tau. If the blocklace BB is leader-live with probability 1 then any b∈Bb\\in B appears eventually in the output of τ\\tau with probability 1, which is the liveness requirement of ordering consensus protocols (Def. [1](#Thmtheorem1 "Definition 1 (Safety and Liveness of an Ordering Consensus Protocol). ‣ 2 Model and Problem Definition ‣ Cordial Miners: Fast and Efficient Consensus for Every Eventuality")). Hence the Cordial Miners protocols are live. ∎

## Appendix D Future Direction and Optimizations

Several optimizations are possible to the protocol instances presented, which we intend to explore in future work:

-   •
    
    As faulty miners are exposed, they are repelled and therefore need not be counted as parties to the agreement, which means that the number of remaining faulty miners, initially bounded by ff, decreases. As a result, the supermajority needed for finality is not n+f2​n\\frac{n+f}{2n} (namely 2​f+12f+1 votes in case n\=3​f+1n=3f+1), but n+f−2​f′2​(n−f′)\\frac{n+f-2f^{\\prime}}{2(n-f^{\\prime})}, where f′f^{\\prime} is the number of exposed faulty miners, which converges to a simple majority (12\\frac{1}{2}) among the correct miners as more faulty miners are exposed and f′f^{\\prime} tends to ff.
    
-   •
    
    Once faulty miners are exposed and repelled, their slots as leaders could be taken by correct miners, improving the good cases and expected complexity.
    
-   •
    
    A hybrid protocol in the spirit of Bullshark \[[33](#bib.bib33)\] can be explored. Such a protocol would employ two leaders per round – deterministic and random, try to achieve quick finality with the deterministic leader, and fall back to the randomly-selected leader if this attempt fails.
    
-   •
    
    Bullshark makes a key observation that fairness (namely, that every block of a correct miner eventually is output by τ\\tau) and garbage collection cannot be achieved together in asynchronous networks. Rather, fairness can be achieved in synchronous periods, and therefore in the ES version of Cordial Miners one can achieve fairness after GST and also garbage collect old blocks in the blocklace. We plan to use similar techniques as Bullshark does for garbage collection.
    
-   •
    
    Exclusion of non-responsive miners: A miner pp need not be cordial to miner qq as long as qq has not observed a previous block bb sent to qq by pp. If qq fail-stopped, then pp should definitely not waste resources on qq; if qq is only suspended or delayed, then eventually it will send to pp a block observing bb, following which pp—being cordial—will send to qq the backlog pp has previously refrained from sending, and is not observed by the new block received from qq.
    

Experimental support, please [view the build logs](./2205.09174v6/__stdout.txt) for errors. Generated by [L A T E xml ![[LOGO]](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAOCAYAAAD5YeaVAAAAAXNSR0IArs4c6QAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB9wKExQZLWTEaOUAAAAddEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIFRoZSBHSU1Q72QlbgAAAdpJREFUKM9tkL+L2nAARz9fPZNCKFapUn8kyI0e4iRHSR1Kb8ng0lJw6FYHFwv2LwhOpcWxTjeUunYqOmqd6hEoRDhtDWdA8ApRYsSUCDHNt5ul13vz4w0vWCgUnnEc975arX6ORqN3VqtVZbfbTQC4uEHANM3jSqXymFI6yWazP2KxWAXAL9zCUa1Wy2tXVxheKA9YNoR8Pt+aTqe4FVVVvz05O6MBhqUIBGk8Hn8HAOVy+T+XLJfLS4ZhTiRJgqIoVBRFIoric47jPnmeB1mW/9rr9ZpSSn3Lsmir1fJZlqWlUonKsvwWwD8ymc/nXwVBeLjf7xEKhdBut9Hr9WgmkyGEkJwsy5eHG5vN5g0AKIoCAEgkEkin0wQAfN9/cXPdheu6P33fBwB4ngcAcByHJpPJl+fn54mD3Gg0NrquXxeLRQAAwzAYj8cwTZPwPH9/sVg8PXweDAauqqr2cDjEer1GJBLBZDJBs9mE4zjwfZ85lAGg2+06hmGgXq+j3+/DsixYlgVN03a9Xu8jgCNCyIegIAgx13Vfd7vdu+FweG8YRkjXdWy329+dTgeSJD3ieZ7RNO0VAXAPwDEAO5VKndi2fWrb9jWl9Esul6PZbDY9Go1OZ7PZ9z/lyuD3OozU2wAAAABJRU5ErkJggg==)](https://math.nist.gov/~BMiller/LaTeXML/)  .

## Instructions for reporting errors

We are continuing to improve HTML versions of papers, and your feedback helps enhance accessibility and mobile support. To report errors in the HTML that will help us improve conversion and rendering, choose any of the methods listed below:

-   Click the "Report Issue" ( ) button, located in the page header.

**Tip:** You can select the relevant text first, to include it in your report.

Our team has already identified [the following issues](https://github.com/arXiv/html_feedback/issues). We appreciate your time reviewing and reporting rendering errors we may not have found yet. Your efforts will help us improve the HTML versions for all readers, because disability should not be a barrier to accessing research. Thank you for your continued support in championing open access for all.

Have a free development cycle? Help support accessibility at arXiv! Our collaborators at LaTeXML maintain a [list of packages that need conversion](https://github.com/brucemiller/LaTeXML/wiki/Porting-LaTeX-packages-for-LaTeXML), and welcome [developer contributions](https://github.com/brucemiller/LaTeXML/issues).

We gratefully acknowledge support from our **major funders**, [**member institutions**](https://info.arxiv.org/about/ourmembers.html), , and all contributors.

[About](https://info.arxiv.org/about) · [Help](https://info.arxiv.org/help) · [Contact](https://info.arxiv.org/help/contact.html) · [Subscribe](https://info.arxiv.org/help/subscribe) · [Copyright](https://info.arxiv.org/help/license/index.html) · [Privacy](https://info.arxiv.org/help/policies/privacy_policy.html) · [Accessibility](https://info.arxiv.org/help/web_accessibility.html) · [Operational Status (opens in new tab)](https://status.arxiv.org)

Major funding support from

 [![Simons Foundation](/static/base/1.0.1/images/funders/simons-foundation.png)](https://www.simonsfoundation.org/)[![Simons Foundation International](/static/base/1.0.1/images/funders/simons-foundation-international.png) ](https://www.sfi.org.bm/)[![Schmidt Sciences](/static/base/1.0.1/images/funders/schmidt-sciences.png)](https://www.schmidtsciences.org/)

[](javascript:toggleReadingMode\(\); "Disable reading mode, show header and footer")