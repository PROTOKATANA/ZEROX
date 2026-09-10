 ALGORAND          

##### Report GitHub Issue

×

Title: 

Content selection saved. Describe the issue below:

Description:

Submit without GitHub Submit in GitHub

![](/static/base/1.0.1/images/icons/smileybones-small.svg) arXiv is now an independent nonprofit! [Learn more](https://info.arxiv.org/about) ×

 [![arXiv logo](/static/base/1.0.1/images/arxiv-logo-primary-light.svg) Back to arXiv](/)

[Why HTML?](https://info.arxiv.org/about/accessible_HTML.html) [Report Issue](# "Report an Issue") [Back to Abstract](/abs/1607.01341v9 "Back to abstract page") [Download PDF](/pdf/1607.01341v9 "Download PDF")[](javascript:toggleNavTOC\(\); "Toggle navigation")[](javascript:toggleReadingMode\(\); "Disable reading mode, show header and footer")

1.  [1 Introduction](#S1 "In ALGORAND")
    1.  [1.1 Bitcoin’s Assumption and Technical Problems](#S1.SS1 "In 1 Introduction ‣ ALGORAND")
        1.  [Assumption: Honest Majority of Computational Power](#S1.SS1.SSS0.Px1 "In 1.1 Bitcoin’s Assumption and Technical Problems ‣ 1 Introduction ‣ ALGORAND")
        2.  [Technical Problem 1: Computational Waste](#S1.SS1.SSS0.Px2 "In 1.1 Bitcoin’s Assumption and Technical Problems ‣ 1 Introduction ‣ ALGORAND")
        3.  [Technical Problem 2: Concentration of Power](#S1.SS1.SSS0.Px3 "In 1.1 Bitcoin’s Assumption and Technical Problems ‣ 1 Introduction ‣ ALGORAND")
        4.  [Technical Problem 3: Ambiguity](#S1.SS1.SSS0.Px4 "In 1.1 Bitcoin’s Assumption and Technical Problems ‣ 1 Introduction ‣ ALGORAND")
    2.  [1.2 Algorand, in a Nutshell](#S1.SS2 "In 1 Introduction ‣ ALGORAND")
        1.  [Setting](#S1.SS2.SSS0.Px1 "In 1.2 Algorand, in a Nutshell ‣ 1 Introduction ‣ ALGORAND")
        2.  [Main Properties](#S1.SS2.SSS0.Px2 "In 1.2 Algorand, in a Nutshell ‣ 1 Introduction ‣ ALGORAND")
        3.  [Algorand’s Techniques.](#S1.SS2.SSS0.Px3 "In 1.2 Algorand, in a Nutshell ‣ 1 Introduction ‣ ALGORAND")
        4.  [An Additional Property/Technique: Lazy Honesty](#S1.SS2.SSS0.Px4 "In 1.2 Algorand, in a Nutshell ‣ 1 Introduction ‣ ALGORAND")
    3.  [1.3 Closely Related work](#S1.SS3 "In 1 Introduction ‣ ALGORAND")
2.  [2 Preliminaries](#S2 "In ALGORAND")
    1.  [2.1 Cryptographic Primitives](#S2.SS1 "In 2 Preliminaries ‣ ALGORAND")
        1.  [Ideal Hashing.](#S2.SS1.SSS0.Px1 "In 2.1 Cryptographic Primitives ‣ 2 Preliminaries ‣ ALGORAND")
        2.  [Digital Signing.](#S2.SS1.SSS0.Px2 "In 2.1 Cryptographic Primitives ‣ 2 Preliminaries ‣ ALGORAND")
        3.  [Unique Digital Signing.](#S2.SS1.SSS0.Px3 "In 2.1 Cryptographic Primitives ‣ 2 Preliminaries ‣ ALGORAND")
        4.  [Remarks](#S2.SS1.SSS0.Px4 "In 2.1 Cryptographic Primitives ‣ 2 Preliminaries ‣ ALGORAND")
    2.  [2.2 The Idealized Public Ledger](#S2.SS2 "In 2 Preliminaries ‣ ALGORAND")
        1.  [Discussion.](#S2.SS2.SSS0.Px1 "In 2.2 The Idealized Public Ledger ‣ 2 Preliminaries ‣ ALGORAND")
    3.  [2.3 Basic Notions and Notations](#S2.SS3 "In 2 Preliminaries ‣ ALGORAND")
        1.  [Keys, Users, and Owners](#S2.SS3.SSS0.Px1 "In 2.3 Basic Notions and Notations ‣ 2 Preliminaries ‣ ALGORAND")
        2.  [Permissionless and Permissioned Systems.](#S2.SS3.SSS0.Px2 "In 2.3 Basic Notions and Notations ‣ 2 Preliminaries ‣ ALGORAND")
        3.  [Unique Representation](#S2.SS3.SSS0.Px3 "In 2.3 Basic Notions and Notations ‣ 2 Preliminaries ‣ ALGORAND")
        4.  [Same-Speed Clocks](#S2.SS3.SSS0.Px4 "In 2.3 Basic Notions and Notations ‣ 2 Preliminaries ‣ ALGORAND")
        5.  [Rounds](#S2.SS3.SSS0.Px5 "In 2.3 Basic Notions and Notations ‣ 2 Preliminaries ‣ ALGORAND")
        6.  [Payments](#S2.SS3.SSS0.Px6 "In 2.3 Basic Notions and Notations ‣ 2 Preliminaries ‣ ALGORAND")
        7.  [Paysets](#S2.SS3.SSS0.Px7 "In 2.3 Basic Notions and Notations ‣ 2 Preliminaries ‣ ALGORAND")
        8.  [Official Paysets](#S2.SS3.SSS0.Px8 "In 2.3 Basic Notions and Notations ‣ 2 Preliminaries ‣ ALGORAND")
    4.  [2.4 Blocks and Proven Blocks](#S2.SS4 "In 2 Preliminaries ‣ ALGORAND")
        1.  [Discussion](#S2.SS4.SSS0.Px1 "In 2.4 Blocks and Proven Blocks ‣ 2 Preliminaries ‣ ALGORAND")
    5.  [2.5 Acceptable Failure Probability](#S2.SS5 "In 2 Preliminaries ‣ ALGORAND")
        1.  [Discussion](#S2.SS5.SSS0.Px1 "In 2.5 Acceptable Failure Probability ‣ 2 Preliminaries ‣ ALGORAND")
    6.  [2.6 The Adversarial Model](#S2.SS6 "In 2 Preliminaries ‣ ALGORAND")
        1.  [Honest and Malicious Users](#S2.SS6.SSS0.Px1 "In 2.6 The Adversarial Model ‣ 2 Preliminaries ‣ ALGORAND")
        2.  [The Adversary](#S2.SS6.SSS0.Px2 "In 2.6 The Adversarial Model ‣ 2 Preliminaries ‣ ALGORAND")
        3.  [Honesty Majority of Money](#S2.SS6.SSS0.Px3 "In 2.6 The Adversarial Model ‣ 2 Preliminaries ‣ ALGORAND")
        4.  [Discussion.](#S2.SS6.SSS0.Px4 "In 2.6 The Adversarial Model ‣ 2 Preliminaries ‣ ALGORAND")
    7.  [2.7 The Communication Model](#S2.SS7 "In 2 Preliminaries ‣ ALGORAND")
        1.  [Temporary Assumption: Timely Delivery of Messages in the Entire Network.](#S2.SS7.SSS0.Px1 "In 2.7 The Communication Model ‣ 2 Preliminaries ‣ ALGORAND")
        2.  [Message Propagation (MP) Assumption:](#S2.SS7.SSS0.Px2 "In 2.7 The Communication Model ‣ 2 Preliminaries ‣ ALGORAND")
        3.  [Note](#S2.SS7.SSS0.Px3 "In 2.7 The Communication Model ‣ 2 Preliminaries ‣ ALGORAND")
3.  [3 The BA Protocol 𝑩​𝑨⋆\\bm{BA^{\\star}} in a Traditional Setting](#S3 "In ALGORAND")
    1.  [3.1 Synchronous Complete Networks and Matching Adversaries](#S3.SS1 "In 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
        1.  [Remarks](#S3.SS1.SSS0.Px1 "In 3.1 Synchronous Complete Networks and Matching Adversaries ‣ 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
    2.  [3.2 The Notion of a Byzantine Agreement](#S3.SS2 "In 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
    3.  [3.3 The BA Notation #\\bm{\\#}](#S3.SS3 "In 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
    4.  [3.4 The Binary BA Protocol 𝑩​𝑩​𝑨⋆\\bm{BBA^{\\star}}](#S3.SS4 "In 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
        1.  [Historical Remark](#S3.SS4.SSS0.Px1 "In 3.4 The Binary BA Protocol 𝑩⁢𝑩⁢𝑨^⋆ ‣ 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
    5.  [3.5 GradedConsensusandtheProtocolGC](#S3.SS5 "In 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
        1.  [Historical Note](#S3.SS5.SSS0.Px1 "In 3.5 Graded Consensus and the Protocol 𝑮⁢𝑪 ‣ 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
    6.  [3.6 The Protocol 𝑩​𝑨⋆\\bm{BA^{\\star}}](#S3.SS6 "In 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
        1.  [Historical Note](#S3.SS6.SSS0.Px1 "In 3.6 The Protocol 𝑩⁢𝑨^⋆ ‣ 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
        2.  [Generalizing 𝑩​𝑨⋆\\bm{BA^{\\star}} for use in Algorand](#S3.SS6.SSS0.Px2 "In 3.6 The Protocol 𝑩⁢𝑨^⋆ ‣ 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND")
4.  [4 Two Embodiments of Algorand](#S4 "In ALGORAND")
    1.  [4.1 A Common Core](#S4.SS1 "In 4 Two Embodiments of Algorand ‣ ALGORAND")
        1.  [Objectives](#S4.SS1.SSS0.Px1 "In 4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
        2.  [Led Byzantine Agreement](#S4.SS1.SSS0.Px2 "In 4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
        3.  [Leader Selection](#S4.SS1.SSS0.Px3 "In 4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
        4.  [Verifier Selection](#S4.SS1.SSS0.Px4 "In 4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
        5.  [Clarifying Block Generation](#S4.SS1.SSS0.Px5 "In 4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
        6.  [Asynchrony and Timing](#S4.SS1.SSS0.Px6 "In 4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
        7.  [The Seed 𝐐𝐫{\\mathbf{Q}}^{\\mathbf{r}} and the Look-Back Parameter 𝒌\\bm{k}](#S4.SS1.SSS0.Px7 "In 4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
        8.  [Ephemeral Keys](#S4.SS1.SSS0.Px8 "In 4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
    2.  [4.2 Common Summary of Notations, Notions, and Parameters](#S4.SS2 "In 4 Two Embodiments of Algorand ‣ ALGORAND")
        1.  [Notations](#S4.SS2.SSS0.Px1 "In 4.2 Common Summary of Notations, Notions, and Parameters ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
        2.  [Notions](#S4.SS2.SSS0.Px2 "In 4.2 Common Summary of Notations, Notions, and Parameters ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
        3.  [Parameters](#S4.SS2.SSS0.Px3 "In 4.2 Common Summary of Notations, Notions, and Parameters ‣ 4 Two Embodiments of Algorand ‣ ALGORAND")
5.  [5 Algorand𝟏′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{1}}](#S5 "In ALGORAND")
    1.  [5.1 Additional Notations and Parameters](#S5.SS1 "In 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        1.  [Notations](#S5.SS1.SSS0.Px1 "In 5.1 Additional Notations and Parameters ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        2.  [Parameters](#S5.SS1.SSS0.Px2 "In 5.1 Additional Notations and Parameters ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
    2.  [5.2 Implementing Ephemeral Keys in Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1}](#S5.SS2 "In 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
    3.  [5.3 Matching the Steps of Algorand𝟏′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{1}} with those of 𝑩​𝑨⋆\\bm{BA^{\\star}}](#S5.SS3 "In 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
    4.  [5.4 The Actual Protocol](#S5.SS4 "In 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        1.  [Remark.](#S5.SS4.SSS0.Px1 "In 5.4 The Actual Protocol ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
    5.  [5.5 Analysis of Algorand𝟏′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{1}}](#S5.SS5 "In 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
    6.  [5.6 Main Theorem](#S5.SS6 "In 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        1.  [Remarks.](#S5.SS6.SSS0.Px1 "In 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
    7.  [5.7 The Completeness Lemma](#S5.SS7 "In 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        1.  [Step 1.](#S5.SS7.SSS0.Px1 "In 5.7 The Completeness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        2.  [Step 2.](#S5.SS7.SSS0.Px2 "In 5.7 The Completeness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        3.  [Step 3.](#S5.SS7.SSS0.Px3 "In 5.7 The Completeness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        4.  [Step 4.](#S5.SS7.SSS0.Px4 "In 5.7 The Completeness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        5.  [Step 5.](#S5.SS7.SSS0.Px5 "In 5.7 The Completeness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        6.  [Step s\>5s>5.](#S5.SS7.SSS0.Px6 "In 5.7 The Completeness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        7.  [Reconstruction of the Round-rr Block.](#S5.SS7.SSS0.Px7 "In 5.7 The Completeness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
    8.  [5.8 The Soundness Lemma](#S5.SS8 "In 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        1.  [GC.](#S5.SS8.SSS0.Px1 "In 5.8 The Soundness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
        2.  [𝑩​𝑩​𝑨⋆\\bm{BBA^{\\star}}.](#S5.SS8.SSS0.Px2 "In 5.8 The Soundness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
    9.  [5.9 Security of the Seed 𝑸𝒓\\bm{Q^{r}} and Probability of An Honest Leader](#S5.SS9 "In 5 \"Algorand\"^′_𝟏 ‣ ALGORAND")
6.  [6 Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}](#S6 "In ALGORAND")
    1.  [6.1 Additional Notations and Parameters for Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}](#S6.SS1 "In 6 \"Algorand\"^′_𝟐 ‣ ALGORAND")
        1.  [Notations](#S6.SS1.SSS0.Px1 "In 6.1 Additional Notations and Parameters for \"Algorand\"^′_𝟐 ‣ 6 \"Algorand\"^′_𝟐 ‣ ALGORAND")
        2.  [Parameters](#S6.SS1.SSS0.Px2 "In 6.1 Additional Notations and Parameters for \"Algorand\"^′_𝟐 ‣ 6 \"Algorand\"^′_𝟐 ‣ ALGORAND")
    2.  [6.2 Implementing Ephemeral Keys in Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2}](#S6.SS2 "In 6 \"Algorand\"^′_𝟐 ‣ ALGORAND")
    3.  [6.3 The Actual Protocol Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}](#S6.SS3 "In 6 \"Algorand\"^′_𝟐 ‣ ALGORAND")
        1.  [Remark.](#S6.SS3.SSS0.Px1 "In 6.3 The Actual Protocol \"Algorand\"^′_𝟐 ‣ 6 \"Algorand\"^′_𝟐 ‣ ALGORAND")
    4.  [6.4 Analysis of Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}](#S6.SS4 "In 6 \"Algorand\"^′_𝟐 ‣ ALGORAND")
7.  [7 Handling Offline Honest users](#S7 "In ALGORAND")
    1.  [From Continual Participation to Lazy Honesty](#S7.SS0.SSS0.Px1 "In 7 Handling Offline Honest users ‣ ALGORAND")
8.  [8 Protocol Algorand′\\bm{\\text{{Algorand}}\\,^{\\prime}} with Honest Majority of Money](#S8 "In ALGORAND")
    1.  [Number of Copies](#S8.SS0.SSSx2.Px1 "In A More Complex Implementation ‣ 8 Protocol \"Algorand\"^′ with Honest Majority of Money ‣ ALGORAND")
    2.  [Verifiers and Credentials](#S8.SS0.SSSx2.Px2 "In A More Complex Implementation ‣ 8 Protocol \"Algorand\"^′ with Honest Majority of Money ‣ ALGORAND")
    3.  [Business as Usual](#S8.SS0.SSSx2.Px3 "In A More Complex Implementation ‣ 8 Protocol \"Algorand\"^′ with Honest Majority of Money ‣ ALGORAND")
9.  [9 Handling Forks](#S9 "In ALGORAND")
10.  [10 Handling Network Partitions](#S10 "In ALGORAND")
    1.  [10.1 Physical Partitions](#S10.SS1 "In 10 Handling Network Partitions ‣ ALGORAND")
        1.  [Additional Instructions for Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}.](#S10.SS1.SSS0.Px1 "In 10.1 Physical Partitions ‣ 10 Handling Network Partitions ‣ ALGORAND")
    2.  [10.2 Adversarial Partition](#S10.SS2 "In 10 Handling Network Partitions ‣ ALGORAND")
    3.  [10.3 Network Partitions in Sum](#S10.SS3 "In 10 Handling Network Partitions ‣ ALGORAND")
11.  [References](#bib "In ALGORAND")

[License: arXiv.org perpetual non-exclusive license](https://info.arxiv.org/help/license/index.html#licenses-available)

arXiv:1607.01341v9 \[cs.CR\] 26 May 2017

# ALGORAND

This is the more formal (and asynchronous) version of the ArXiv paper by the second author \[[24](#bib.bib24)\], a paper itself based on that of Gorbunov and Micali \[[18](#bib.bib18)\]. Algorand’s technologies are the object of the following patent applications: US62/117,138 US62/120,916 US62/142,318 US62/218,817 US62/314,601 PCT/US2016/018300 US62/326,865 62/331,654 US62/333,340 US62/343,369 US62/344,667 US62/346,775 US62/351,011 US62/653,482 US62/352,195 US62/363,970 US62/369,447 US62/378,753 US62/383,299 US62/394,091 US62/400,361 US62/403,403 US62/410,721 US62/416,959 US62/422,883 US62/455,444 US62/458,746 US62/459,652 US62/460,928 US62/465,931

Jing Chen Affiliation: Computer Science Department Affiliation: Stony Brook University Affiliation: Stony Brook, NY 11794, USA Email: [jingchen@cs.stonybrook.edu](mailto:jingchen@cs.stonybrook.edu)    Silvio Micali Affiliation: CSAIL Affiliation: MIT Affiliation: Cambridge, MA 02139, USA Email: [silvio@csail.mit.edu](mailto:silvio@csail.mit.edu)

Abstract

A public ledger is a tamperproof sequence of data that can be read and augmented by everyone. Public ledgers have innumerable and compelling uses. They can secure, in plain sight, all kinds of transactions —such as titles, sales, and payments— in the exact order in which they occur. Public ledgers not only curb corruption, but also enable very sophisticated applications —such as cryptocurrencies and smart contracts. They stand to revolutionize the way a democratic society operates. As currently implemented, however, they scale poorly and cannot achieve their potential.

Algorand is a truly democratic and efficient way to implement a public ledger. Unlike prior implementations based on proof of work, it requires a negligible amount of computation, and generates a transaction history that will not “fork” with overwhelmingly high probability.

Algorand is based on (a novel and super fast) message-passing Byzantine agreement.

For concreteness, we shall describe Algorand only as a money platform.

## 1 Introduction

Money is becoming increasingly virtual. It has been estimated that about 80% of United States dollars today only exist as ledger entries \[[5](#bib.bib5)\]. Other financial instruments are following suit.

In an ideal world, in which we could count on a universally trusted central entity, immune to all possible cyber attacks, money and other financial transactions could be solely electronic. Unfortunately, we do not live in such a world. Accordingly, decentralized cryptocurrencies, such as Bitcoin \[[29](#bib.bib29)\], and “smart contract” systems, such as Ethereum, have been proposed \[[4](#bib.bib4)\]. At the heart of these systems is a shared *ledger* that reliably records a sequence of transactions, as varied as payments and contracts, in a tamperproof way. The technology of choice to guarantee such tamperproofness is the blockchain. Blockchains are behind applications such as cryptocurrencies \[[29](#bib.bib29)\], financial applications \[[4](#bib.bib4)\], and the Internet of Things \[[3](#bib.bib3)\]. Several techniques to manage blockchain-based ledgers have been proposed: *proof of work* \[[29](#bib.bib29)\], *proof of stake* \[[2](#bib.bib2)\], *practical Byzantine fault-tolerance* \[[8](#bib.bib8)\], or some combination.

Currently, however, ledgers can be inefficient to manage. For example, Bitcoin’s *proof-of-work* approach (based on the original concept of \[[14](#bib.bib14)\]) requires a vast amount of computation, is wasteful and scales poorly \[[1](#bib.bib1)\]. In addition, it de facto concentrates power in very few hands.

We therefore wish to put forward a new method to implement a public ledger that offers the convenience and efficiency of a centralized system run by a trusted and inviolable authority, without the inefficiencies and weaknesses of current decentralized implementations. We call our approach Algorand, because we use algorithmic randomness to select, based on the ledger constructed so far, a set of verifiers who are in charge of constructing the next block of valid transactions. Naturally, we ensure that such selections are provably immune from manipulations and unpredictable until the last minute, but also that they ultimately are universally clear.

Algorand’s approach is quite democratic, in the sense that neither in principle nor de facto it creates different classes of users (as “miners” and “ordinary users” in Bitcoin). In Algorand “all power resides with the set of all users”.

One notable property of Algorand is that its transaction history may fork only with very small probability (e.g., one in a trillion, that is, or even 10−1810^{-18}). Algorand can also address some legal and political concerns.

The Algorand approach applies to blockchains and, more generally, to any method of generating a tamperproof sequence of blocks. We actually put forward a new method —alternative to, and more efficient than, blockchains— that may be of independent interest.

### 1.1 Bitcoin’s Assumption and Technical Problems

Bitcoin is a very ingenious system and has inspired a great amount of subsequent research. Yet, it is also problematic. Let us summarize its underlying assumption and technical problems —which are actually shared by essentially all cryptocurrencies that, like Bitcoin, are based on proof-of-work.

For this summary, it suffices to recall that, in Bitcoin, a user may own multiple public keys of a digital signature scheme, that money is associated with public keys, and that a payment is a digital signature that transfers some amount of money from one public key to another. Essentially, Bitcoin organizes all processed payments in a chain of blocks, B1,B2,…B\_{1},B\_{2},\\ldots, each consisting of multiple payments, such that, all payments of B1B\_{1}, taken in any order, followed by those of B2B\_{2}, in any order, etc., constitute a sequence of valid payments. Each block is generated, on average, every 10 minutes.

This sequence of blocks is a *chain*, because it is structured so as to ensure that any change, even in a single block, percolates into all subsequent blocks, making it easier to spot any alteration of the payment history. (As we shall see, this is achieved by including in each block a cryptographic hash of the previous one.) Such block structure is referred to as a *blockchain*.

##### Assumption: Honest Majority of Computational Power

Bitcoin assumes that no malicious entity (nor a coalition of coordinated malicious entities) controls the majority of the computational power devoted to block generation. Such an entity, in fact, would be able to modify the blockchain, and thus re-write the payment history, as it pleases. In particular, it could make a payment ℘\\wp, obtain the benefits paid for, and then “erase” any trace of ℘\\wp.

##### Technical Problem 1: Computational Waste

Bitcoin’s proof-of-work approach to block generation requires an extraordinary amount of computation. Currently, with just a few hundred thousands public keys in the system, the top 500 most powerful supercomputers can only muster a mere 12.8% percent of the total computational power required from the Bitcoin players. This amount of computation would greatly increase, should significantly more users join the system.

##### Technical Problem 2: Concentration of Power

Today, due to the exorbitant amount of computation required, a user, trying to generate a new block using an ordinary desktop (let alone a cell phone), expects to lose money. Indeed, for computing a new block with an ordinary computer, the expected cost of the necessary electricity to power the computation exceeds the expected reward. Only using *pools* of specially built computers (that do nothing other than “mine new blocks”), one might expect to make a profit by generating new blocks. Accordingly, today there are, de facto, two disjoint classes of users: ordinary users, who only make payments, and specialized mining pools, that only search for new blocks.

It should therefore not be a surprise that, as of recently, the total computing power for block generation lies within just five pools. In such conditions, the assumption that a majority of the computational power is honest becomes less credible.

##### Technical Problem 3: Ambiguity

In Bitcoin, the blockchain is not necessarily unique. Indeed its latest portion often forks: the blockchain may be —say— B1,…,Bk,Bk+1′,Bk+2′B\_{1},\\ldots,B\_{k},B\_{k+1}^{\\prime},B\_{k+2}^{\\prime}, according to one user, and B1,…,Bk,Bk+1′′,Bk+2′′,Bk+3′′B\_{1},\\ldots,B\_{k},B\_{k+1}^{\\prime\\prime},B\_{k+2}^{\\prime\\prime},B\_{k+3}^{\\prime\\prime} according another user. Only after several blocks have been added to the chain, can one be reasonably sure that the first k+3k+3 blocks will be the same for all users. Thus, one cannot rely right away on the payments contained in the last block of the chain. It is more prudent to wait and see whether the block becomes sufficiently deep in the blockchain and thus sufficiently stable.

Separately, law-enforcement and monetary-policy concerns have also been raised about Bitcoin.11 1 The (pseudo) anonymity offered by Bitcoin payments may be misused for money laundering and/or the financing of criminal individuals or terrorist organizations. Traditional banknotes or gold bars, that in principle offer perfect anonymity, should pose the same challenge, but the physicality of these currencies substantially slows down money transfers, so as to permit some degree of monitoring by law-enforcement agencies. The ability to “print money” is one of the very basic powers of a nation state. In principle, therefore, the massive adoption of an independently floating currency may curtail this power. Currently, however, Bitcoin is far from being a threat to governmental monetary policies, and, due to its scalability problems, may never be.

### 1.2 Algorand, in a Nutshell

##### Setting

Algorand works in a very tough setting. Briefly,

-   (a)
    
    Permissionless and Permissioned Environments. Algorand works efficiently and securely even in a totally permissionless environment, where arbitrarily many users are allowed to join the system at any time, without any vetting or permission of any kind. Of course, Algorand works even better in a permissioned environment.
    
-   (b)
    
    Very Adversarial Environments. Algorand withstands a very powerful Adversary, who can
    
    (1) instantaneously corrupt any user he wants, at any time he wants, provided that, in a permissionless environment, 2/3 of the money in the system belongs to honest user. (In a permissioned environment, irrespective of money, it suffices that 2/3 of the users are honest.)
    
    (2) totally control and perfectly coordinate all corrupted users; and
    
    (3) schedule the delivery of all messages, provided that each message mm sent by a honest user reaches 95% of the honest users within a time λm\\lambda\_{m}, which solely depends on the size of mm.
    

##### Main Properties

Despite the presence of our powerful adversary, in Algorand

-   •
    
    The amount of computation required is minimal. Essentially, no matter how many users are present in the system, each of fifteen hundred users must perform at most a few seconds of computation.
    
-   •
    
    A New Block is Generated in less than 10 minutes, and will de facto never leave the blockchain. For instance, in expectation, the time to generate a block in the first embodiment is less than Λ+12.4​λ\\Lambda+12.4\\lambda, where Λ\\Lambda is the time necessary to propagate a block, in a peer-to-peer gossip fashion, no matter what block size one may choose, and λ\\lambda is the time to propagate 1,500 200B-long messages. (Since in a truly decentralized system, Λ\\Lambda essentially is an intrinsic latency, in Algorand the limiting factor in block generation is network speed.) The second embodiment has actually been tested experimentally ( by ?), indicating that a block is generated in less than 40 seconds.
    
    In addition, Algorand’s blockchain may fork only with negligible probability (i.e., less than one in a trillion), and thus users can relay on the payments contained in a new block as soon as the block appears.
    
-   •
    
    All power resides with the users themselves. Algorand is a truy distributed system. In particular, there are no exogenous entities (as the “miners” in Bitcoin), who can control which transactions are recognized.
    

##### Algorand’s Techniques.

1\. A New and Fast Byzantine Agreement Protocol. Algorand generates a new block via a new cryptographic, message-passing, binary Byzantine agreement (BA) protocol, B​A⋆BA^{\\star}. Protocol B​A⋆BA^{\\star} not only satisfies some additional properties (that we shall soon discuss), but is also very fast. Roughly said, its binary-input version consists of a 3-step loop, in which a player ii sends a single message mim\_{i} to all other players. Executed in a complete and synchronous network, with more than 2/3 of the players being honest, with probability \>1/3\>1/3, after each loop the protocol ends in agreement. (We stress that protocol B​A⋆BA^{\\star} satisfies the original definition of Byzantine agreement of Pease, Shostak, and Lamport \[[31](#bib.bib31)\], without any weakenings.)

Algorand leverages this binary BA protocol to reach agreement, in our different communication model, on each new block. The agreed upon block is then certified, via a prescribed number of digital signature of the proper verifiers, and propagated through the network.

2\. Cryptographic Sortition. Although very fast, protocol B​A⋆BA^{\\star} would benefit from further speed when played by millions of users. Accordingly, Algorand chooses the players of B​A⋆BA^{\\star} to be a much smaller subset of the set of all users. To avoid a different kind of concentration-of-power problem, each new block BrB^{r} will be constructed and agreed upon, via a new execution of B​A⋆BA^{\\star}, by a separate set of selected verifiers, S​VrSV^{r}. In principle, selecting such a set might be as hard as selecting BrB^{r} directly. We traverse this potential problem by an approach that we term, embracing the insightful suggestion of Maurice Herlihy, cryptographic sortition. Sortition is the practice of selecting officials at random from a large set of eligible individuals \[[6](#bib.bib6)\]. (Sortition was practiced across centuries: for instance, by the republics of Athens, Florence, and Venice. In modern judicial systems, random selection is often used to choose juries. Random sampling has also been recently advocated for elections by David Chaum \[[9](#bib.bib9)\].) In a decentralized system, of course, choosing the random coins necessary to randomly select the members of each verifier set S​VrSV^{r} is problematic. We thus resort to cryptography in order to select each verifier set, from the population of all users, in a way that is guaranteed to be automatic (i.e., requiring no message exchange) and random. In essence, we use a cryptographic function to automatically determine, from the previous block Br−1B^{r-1}, a user, the leader, in charge of proposing the new block BrB^{r}, and the verifier set S​VrSV^{r}, in charge to reach agreement on the block proposed by the leader. Since malicious users can affect the composition of Br−1B^{r-1} (e.g., by choosing some of its payments), we specially construct and use additional inputs so as to prove that the leader for the rrth block and the verifier set S​VrSV^{r} are indeed randomly chosen.

3\. The Quantity (Seed) Qr{Q^{r}}. We use the the last block Br−1B^{r-1} in the blockchain in order to automatically determine the next verifier set and leader in charge of constructing the new block BrB^{r}. The challenge with this approach is that, by just choosing a slightly different payment in the previous round, our powerful Adversary gains a tremendous control over the next leader. Even if he only controlled only 1/1000 of the players/money in the system, he could ensure that all leaders are malicious. (See the Intuition Section [4.1](#S4.SS1 "4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND").) This challenge is central to all proof-of-stake approaches, and, to the best of our knowledge, it has not, up to now, been satisfactorily solved.

To meet this challenge, we purposely construct, and continually update, a separate and carefully defined quantity, QrQ^{r}, which provably is, not only unpredictable, but also not influentiable, by our powerful Adversary. We may refer to QrQ^{r} as the rrth seed, as it is from QrQ^{r} that Algorand selects, via secret cryptographic sortition, all the users that will play a special role in the generation of the rrth block.

4\. Secret Crytographic Sortition and Secret Credentials. Randomly and unambiguously using the current last block, Br−1B^{r-1}, in order to choose the verifier set and the leader in charge of constructing the new block, BrB^{r}, is not enough. Since Br−1B^{r-1} must be known before generating BrB^{r}, the last non-influentiable quantity Qr−1Q^{r-1} contained in Br−1B^{r-1} must be known too. Accordingly, so are the verifiers and the leader in charge to compute the block BrB^{r}. Thus, our powerful Adversary might immediately corrupt all of them, before they engage in any discussion about BrB^{r}, so as to get full control over the block they certify.

To prevent this problem, leaders (and actually verifiers too) secretly learn of their role, but can compute a proper credential, capable of proving to everyone that indeed have that role. When a user privately realizes that he is the leader for the next block, first he secretly assembles his own proposed new block, and then disseminates it (so that can be certified) together with his own credential. This way, though the Adversary will immediately realize who the leader of the next block is, and although he can corrupt him right away, it will be too late for the Adversary to influence the choice of a new block. Indeed, he cannot “call back” the leader’s message no more than a powerful government can put back into the bottle a message virally spread by WikiLeaks.

As we shall see, we cannot guarantee leader uniqueness, nor that everyone is sure who the leader is, including the leader himself! But, in Algorand, unambiguous progress will be guaranteed.

5\. Player Replaceability. After he proposes a new block, the leader might as well “die” (or be corrupted by the Adversary), because his job is done. But, for the verifiers in S​VrSV^{r}, things are less simple. Indeed, being in charge of certifying the new block BrB^{r} with sufficiently many signatures, they must first run Byzantine agreement on the block proposed by the leader. The problem is that, no matter how efficient it is, B​A⋆BA^{\\star} requires multiple steps and the honesty of \>2/3\>2/3 of its players. This is a problem, because, for efficiency reasons, the player set of B​A⋆BA^{\\star} consists the small set S​VrSV^{r} randomly selected among the set of all users. Thus, our powerful Adversary, although unable to corrupt 1/3 of all the users, can certainly corrupt all members of S​VrSV^{r}!

Fortunately we’ll prove that protocol B​A⋆BA^{\\star}, executed by propagating messages in a peer-to-peer fashion, is player-replaceable. This novel requirement means that the protocol correctly and efficiently reaches consensus even if each of its step is executed by a totally new, and randomly and independently selected, set of players. Thus, with millions of users, each small set of players associated to a step of B​A⋆BA^{\\star} most probably has empty intersection with the next set.

In addition, the sets of players of different steps of B​A⋆BA^{\\star} will probably have totally different cardinalities. Furthermore, the members of each set do not know who the next set of players will be, and do not secretly pass any internal state.

The replaceable-player property is actually crucial to defeat the dynamic and very powerful Adversary we envisage. We believe that replaceable-player protocols will prove crucial in lots of contexts and applications. In particular, they will be crucial to execute securely small sub-protocols embedded in a larger universe of players with a dynamic adversary, who, being able to corrupt even a small fraction of the total players, has no difficulty in corrupting all the players in the smaller sub-protocol.

##### An Additional Property/Technique: Lazy Honesty

A honest user follows his prescribed instructions, which include being online and run the protocol. Since, Algorand has only modest computation and communication requirement, being online and running the protocol “in the background” is not a major sacrifice. Of course, a few “absences” among honest players, as those due to sudden loss of connectivity or the need of rebooting, are automatically tolerated (because we can always consider such few players to be temporarily malicious). Let us point out, however, that Algorand can be simply adapted so as to work in a new model, in which honest users to be offline most of the time. Our new model can be informally introduced as follows.

-   Lazy Honesty. Roughly speaking, a user ii is lazy-but-honest if (1) he follows all his prescribed instructions, when he is asked to participate to the protocol, and (2) he is asked to participate to the protocol only rarely, and with a suitable advance notice.
    

With such a relaxed notion of honesty, we may be even more confident that honest people will be at hand when we need them, and Algorand guarantee that, when this is the case,

The system operates securely even if, at a given point in time,  
the majority of the participating players are malicious.

### 1.3 Closely Related work

Proof-of-work approaches (like the cited \[[29](#bib.bib29)\] and \[[4](#bib.bib4)\]) are quite orthogonal to our ours. So are the approaches based on message-passing Byzantine agreement or practical Byzantine fault tolerance (like the cited \[[8](#bib.bib8)\]). Indeed, these protocols cannot be run among the set of all users and cannot, in our model, be restricted to a suitably small set of users. In fact, our powerful adversary my immediately corrupt all the users involved in a small set charged to actually running a BA protocol.

Our approach could be considered related to proof of stake \[[2](#bib.bib2)\], in the sense that users’ “power” in block building is proportional to the money they own in the system (as opposed to —say— to the money they have put in “escrow”).

The paper closest to ours is the Sleepy Consensus Model of Pass and Shi \[[30](#bib.bib30)\]. To avoid the heavy computation required in the proof-of-work approach, their paper relies upon (and kindly credits) Algorand’s secret cryptographic sortition. With this crucial aspect in common, several significant differences exist between our papers. In particular,

(1) Their setting is only permissioned. By contrast, Algorand is also a permissionless system.

(2) They use a Nakamoto-style protocol, and thus their blockchain forks frequently. Although dispensing with proof-of-work, in their protocol a secretly selected leader is asked to elongate the longest valid (in a richer sense) blockchain. Thus, forks are unavoidable and one has to wait that the block is sufficiently “deep” in the chain. Indeed, to achieve their goals with an adversary capable of adaptive corruptions, they require a block to be p​o​l​y​(N)poly(N) deep, where NN represents the total number of users in the system. Notice that, even assuming that a block could be produced in a minute, if there were N\=1​MN=1M users, then one would have to wait for about 2M years for a block to become N2N^{2}\-deep, and for about 2 years for a block to become NN\-deep. By contrast, Algorand’s blockchain forks only with negligible probability, even though the Adversary corrupt users immediately and adaptively, and its new blocks can immediately be relied upon.

(3) They do not handle individual Byzantine agreements. In a sense, they only guarantee “eventual consensus on a growing sequence of values”. Theirs is a state replication protocol, rather than a BA one, and cannot be used to reach Byzantine agreement on an individual value of interest. By contrast, Algorand can also be used only once, if so wanted, to enable millions of users to quickly reach Byzantine agreement on a specific value of interest.

(4) They require weakly synchronized clocks. That is, all users’ clocks are offset by a small time δ\\delta. By contrast, in Algorand, clocks need only have (essentially) the same “speed”.

(5) Their protocol works with lazy-but-honest users or with honest majority of online users. They kindly credit Algorand for raising the issue of honest users going offline en masse, and for putting forward the lazy honesty model in response. Their protocol not only works in the lazy honesty model, but also in their adversarial sleepy model, where an adversary chooses which users are online and which are offline, provided that, at all times, the majority of online users are honest.22 2 The original version of their paper actually considered only security in their adversarial sleepy model. The original version of Algorand, which precedes theirs, also explicitly envisaged assuming that a given majority of the online players is always honest, but explicitly excluded it from consideration, in favor of the lazy honesty model. (For instance, if at some point in time half of the honest users choose to go off-line, then the majority of the users on-line may very well be malicious. Thus, to prevent this from happening, the Adversary should force most of his corrupted players to go off-line too, which clearly is against his own interest.) Notice that a protocol with a majority of lazy-but-honest players works just fine if the majority of the users on-line are always malicious. This is so, because a sufficient number of honest players, knowing that they are going to be crucial at some rare point in time, will elect not to go off-line in those moments, nor can they be forced off-line by the Adversary, since he does not know who the crucial honest players might be.

(6) They require a simple honest majority. By contrast, the current version of Algorand requires a 2/3 honest majority.

Another paper close to us is Ouroboros: A Provably Secure Proof-of-Stake Blockchain Protocol, by Kiayias, Russell, David, and Oliynykov \[[20](#bib.bib20)\]. Also their system appeared after ours. It also uses crytpographic sortition to dispense with proof of work in a provable manner. However, their system is, again, a Nakamoto-style protocol, in which forks are both unavoidable and frequent. (However, in their model, blocks need not as deep as the sleepy-consensus model.) Moreover, their system relies on the following assumptions: in the words of the authors themselves, “(1) the network is highly synchronous, (2) the majority of the selected stakeholders is available as needed to participate in each epoch, (3) the stakeholders do not remain offline for long periods of time, (4) the adaptivity of corruptions is subject to a small delay that is measured in rounds linear in the security parameter.” By contrast, Algorand is, with overwhelming probability, fork-free, and does not rely on any of these 4 assumptions. In particular, in Algorand, the Adversary is able to instantaneously corrupt the users he wants to control.

## 2 Preliminaries

### 2.1 Cryptographic Primitives

##### Ideal Hashing.

We shall rely on an efficiently computable cryptographic hash function, HH, that maps arbitrarily long strings to binary strings of fixed length. Following a long tradition, we model HH as a random oracle, essentially a function mapping each possible string ss to a randomly and independently selected (and then fixed) binary string, H⁡(s)H(s), of the chosen length.

In this paper, HH has 256-bit long outputs. Indeed, such length is short enough to make the system efficient and long enough to make the system secure. For instance, we want HH to be collision-resilient. That is, it should be hard to find two different strings xx and yy such that H⁡(x)\=H⁡(y)H(x)=H(y). When HH is a random oracle with 256-bit long outputs, finding any such pair of strings is indeed difficult. (Trying at random, and relying on the birthday paradox, would require 2256/2\=21282^{256/2}=2^{128} trials.)

##### Digital Signing.

Digital signatures allow users to to authenticate information to each other without sharing any sharing any secret keys. A digital signature scheme consists of three fast algorithms: a probabilistic key generator GG, a signing algorithm SS, and a verification algorithm VV.

Given a security parameter kk, a sufficiently high integer, a user ii uses GG to produce a pair of kk\-bit keys (i.e., strings): a “public” key p​kipk\_{i} and a matching “secret” signing key s​kisk\_{i}. Crucially, a public key does not “betray” its corresponding secret key. That is, even given knowledge of p​kipk\_{i}, no one other than ii is able to compute s​kisk\_{i} in less than astronomical time.

User ii uses s​kisk\_{i} to digitally sign messages. For each possible message (binary string) mm, ii first hashes mm and then runs algorithm SS on inputs H⁡(m)H(m) and s​kisk\_{i} so as to produce the kk\-bit string

s​i​gp​ki​(m)≜S⁡(H⁡(m),s​ki).sig\_{pk\_{i}}(m)\\triangleq S(H(m),sk\_{i})\\kern 5.0pt.

The binary string s​i​gp​ki​(m)sig\_{pk\_{i}}(m) is referred to as ii’s digital signature of mm (relative to p​kipk\_{i}), and can be more simply denoted by s​i​gi​(m)sig\_{i}(m), when the public key p​kipk\_{i} is clear from context.

Everyone knowing p​kipk\_{i} can use it to verify the digital signatures produced by ii. Specifically, on inputs (a) the public key p​kipk\_{i} of a player ii, (b) a message mm, and (c) a string ss, that is, ii’s alleged digital signature of the message mm, the verification algorithm VV outputs either YES or NO.

The properties we require from a digital signature scheme are:

-   1.
    
    Legitimate signatures are always verified: If s\=s​i​gi​(m)s=sig\_{i}(m), then V⁡(p​ki,m,s)\=Y​E​SV(pk\_{i},m,s)=YES; and
    
-   2.
    
    Digital signatures are hard to forge: Without knowledge of s​kisk\_{i} the time to find a string ss such that V⁡(p​ki,m,s)\=Y​E​SV(pk\_{i},m,s)=YES, for a message mm never signed by ii, is astronomically long.
    
    (Following the strong security requirement of Goldwasser, Micali, and Rivest \[[17](#bib.bib17)\], this is true even if one can obtain the signature of any other message.)
    

Accordingly, to prevent anyone else from signing messages on his behalf, a player ii must keep his signing key s​kisk\_{i} secret (hence the term “secret key”), and to enable anyone to verify the messages he does sign, ii has an interest in publicizing his key p​kipk\_{i} (hence the term “public key”).

In general, a message mm is not retrievable from its signature s​i​gi​(m)sig\_{i}(m). In order to virtually deal with digital signatures that satisfy the conceptually convenient “retrievability” property (i.e., to guarantee that the signer and the message are easily computable from a signature, we define

S​I​Gp​ki​(m)\=(i,m,s​i​gp​ki​(m)) and S​I​Gi​(m)\=(i,m,s​i​gi​(m)), if p​ki is clear.SIG\_{pk\_{i}}(m)=(i,m,sig\_{pk\_{i}}(m))\\quad\\text{ and }\\quad SIG\_{i}(m)=(i,m,sig\_{i}(m)),\\text{ if $pk\_{i}$ is clear}.

##### Unique Digital Signing.

We also consider digital signature schemes (G,S,V)(G,S,V) satisfying the following additional property.

-   3.
    
    Uniqueness. It is hard to find strings p​k′pk^{\\prime}, mm, ss, and s′s^{\\prime} such that
    
    s≠s′s\\neq s^{\\prime}  and  V⁡(p​k′,m,s)\=V⁡(p​k′,m,s′)\=1V(pk^{\\prime},m,s)=V(pk^{\\prime},m,s^{\\prime})=1.
    
    (Note that the uniqueness property holds also for strings p​k′pk^{\\prime} that are not legitimately generated public keys. In particular, however, the uniqueness property implies that, if one used the specified key generator GG to compute a public key p​kpk together with a matching secret key s​ksk, and thus knew s​ksk, it would be essentially impossible also for him to find two different digital signatures of a same message relative to p​kpk.)
    

##### Remarks

-   •
    
    From Unique signatures to verifiable random functions. Relative to a digital signature scheme with the uniqueness property, the mapping m→H⁡(s​i​gi​(m))m\\rightarrow H(sig\_{i}(m)) associates to each possible string mm, a unique, randomly selected, 256-bit string, and the correctness of this mapping can be proved given the signature s​i​gi​(m)sig\_{i}(m).
    
    That is, ideal hashing and digital signature scheme satisfying the uniqueness property essentially provide an elementary implementation of a verifiable random function, as introduced and by Micali, Rabin, and Vadhan \[[27](#bib.bib27)\]. (Their original implementation was necessarily more complex, since they did not rely on ideal hashing.)
    
-   •
    
    Three different needs for digital signatures. In Algorand, a user ii relies on digital signatures for
    
    (1) Authenticating ii’s own payments. In this application, keys can be “long-term” (i.e., used to sign many messages over a long period of time) and come from a ordinary signature scheme.
    
    (2) Generating credentials proving that ii is entitled to act at some step ss of a round rr. Here, keys can be long-term, but must come from a scheme satisfying the uniqueness property.
    
    (3) Authenticating the message ii sends in each step in which he acts. Here, keys must be ephemeral (i.e., destroyed after their first use), but can come from an ordinary signature scheme.
    
-   •
    
    A small-cost simplification. For simplicity, we envision each user ii to have a single long-term key. Accordingly, such a key must come from a signature scheme with the uniqueness property. Such simplicity has a small computational cost. Typically, in fact, unique digital signatures are slightly more expensive to produce and verify than ordinary signatures.
    

### 2.2 The Idealized Public Ledger

Algorand tries to mimic the following payment system, based on an idealized public ledger.

-   1.
    
    The Initial Status. Money is associated with individual public keys (privately generated and owned by users). Letting p​k1,…,p​kjpk\_{1},\\ldots,pk\_{j} be the initial public keys and a1,…,aja\_{1},\\ldots,a\_{j} their respective initial amounts of money units, then the initial status is
    
    S0\=(p​k1,a1),…,(p​kj,aj),S\_{0}=(pk\_{1},a\_{1}),\\ldots,(pk\_{j},a\_{j})\\kern 5.0pt,
    
    which is assumed to be common knowledge in the system.
    
-   2.
    
    Payments. Let p​kpk be a public key currently having a≥0a\\geq 0 money units, p​k′pk^{\\prime} another public key, and a′a^{\\prime} a non-negative number no greater than aa. Then, a (valid) payment ℘\\wp is a digital signature, relative to p​kpk, specifying the transfer of a′a^{\\prime} monetary units from p​kpk to p​k′pk^{\\prime}, together with some additional information. In symbols,
    
    ℘\=S​I​Gp​k​(p​k,p​k′,a′,I,H⁡(ℐ)),\\wp=SIG\_{pk}(pk,pk^{\\prime},a^{\\prime},I,H({\\cal I})),
    
    where II represents any additional information deemed useful but not sensitive (e.g., time information and a payment identifier), and ℐ{\\cal I} any additional information deemed sensitive (e.g., the reason for the payment, possibly the identities of the owners of p​kpk and the p​k′pk^{\\prime}, and so on).
    
    We refer to p​kpk (or its owner) as the payer, to each p​k′pk^{\\prime} (or its owner) as a payee, and to a′a^{\\prime} as the amount of the payment ℘\\wp.
    
    Free Joining Via Payments. Note that users may join the system whenever they want by generating their own public/secret key pairs. Accordingly, the public key p​k′pk^{\\prime} that appears in the payment ℘\\wp above may be a newly generated public key that had never “owned” any money before.
    
-   3.
    
    The Magic Ledger. In the Idealized System, all payments are valid and appear in a tamper-proof list LL of sets of payments “posted on the sky” for everyone to see:
    
    L\=P​A​Y1,P​A​Y2,…,L=PAY^{1},PAY^{2},\\ldots,
    
    Each block P​A​Yr+1PAY^{r+1} consists of the set of all payments made since the appearance of block P​A​YrPAY^{r}. In the ideal system, a new block appears after a fixed (or finite) amount of time.
    

##### Discussion.

-   •
    
    More General Payments and Unspent Transaction Output. More generally, if a public key p​kpk owns an amount aa, then a valid payment ℘\\wp of p​kpk may transfer the amounts a1′,a2′,…a\_{1}^{\\prime},a\_{2}^{\\prime},\\ldots, respectively to the keys p​k1′,p​k2′,…pk\_{1}^{\\prime},pk\_{2}^{\\prime},\\ldots, so long as ∑jaj′≤a\\sum\_{j}a\_{j}^{\\prime}\\leq a.
    
    In Bitcoin and similar systems, the money owned by a public key p​kpk is segregated into separate amounts, and a payment ℘\\wp made by p​kpk must transfer such a segregated amount aa in its entirety. If p​kpk wishes to transfer only a fraction a′<aa^{\\prime}<a of aa to another key, then it must also transfer the balance, the unspent transaction output, to another key, possibly p​kpk itself.
    
    Algorand also works with keys having segregated amounts. However, in order to focus on the novel aspects of Algorand, it is conceptually simpler to stick to our simpler forms of payments and keys having a single amount associated to them.
    
-   •
    
    Current Status. The Idealized Scheme does not directly provide information about the current status of the system (i.e., about how many money units each public key has). This information is deducible from the Magic Ledger.
    
    In the ideal system, an active user continually stores and updates the latest status information, or he would otherwise have to reconstruct it, either from scratch, or from the last time he computed it. (In the next version of this paper, we shall augment Algorand so as to enable its users to reconstruct the current status in an efficient manner.)
    
-   •
    
    Security and “Privacy”. Digital signatures guarantee that no one can forge a payment by another user. In a payment ℘\\wp, the public keys and the amount are not hidden, but the sensitive information ℐ{\\cal I} is. Indeed, only H⁡(ℐ)H({\\cal I}) appears in ℘\\wp, and since HH is an ideal hash function, H⁡(ℐ)H({\\cal I}) is a random 256-bit value, and thus there is no way to figure out what ℐ{\\cal I} was better than by simply guessing it. Yet, to prove what ℐ{\\cal I} was (e.g., to prove the reason for the payment) the payer may just reveal ℐ{\\cal I}. The correctness of the revealed ℐ{\\cal I} can be verified by computing H⁡(ℐ)H({\\cal I}) and comparing the resulting value with the last item of ℘\\wp. In fact, since HH is collision resilient, it is hard to find a second value ℐ′{\\cal I}^{\\prime} such that H⁡(ℐ)\=H⁡(ℐ′)H({\\cal I})=H({\\cal I}^{\\prime}).
    

### 2.3 Basic Notions and Notations

##### Keys, Users, and Owners

Unless otherwise specified, each public key (“key” for short) is long-term and relative to a digital signature scheme with the uniqueness property. A public key ii joins the system when another public key jj already in the system makes a payment to ii.

For color, we personify keys. We refer to a key ii as a “he”, say that ii is honest, that ii sends and receives messages, etc. User is a synonym for key. When we want to distinguish a key from the person to whom it belongs, we respectively use the term “digital key” and “owner”.

##### Permissionless and Permissioned Systems.

A system is permissionless, if a digital key is free to join at any time and an owner can own multiple digital keys; and its permissioned, otherwise.

##### Unique Representation

Each object in Algorand has a unique representation. In particular, each set {(x,y,z,…):x∈X,y∈Y,z∈Z,…}\\{(x,y,z,\\ldots):x\\in X,y\\in Y,z\\in Z,\\ldots\\} is ordered in a pre-specified manner: e.g., first lexicographically in xx, then in yy, etc.

##### Same-Speed Clocks

There is no global clock: rather, each user has his own clock. User clocks need not be synchronized in any way. We assume, however, that they all have the same speed.

For instance, when it is 12pm according to the clock of a user ii, it may be 2:30pm according to the clock of another user jj, but when it will be 12:01 according to ii’s clock, it will 2:31 according to jj’s clock. That is, “one minute is the same (sufficiently, essentially the same) for every user”.

##### Rounds

Algorand is organized in logical units, r\=0,1,…r=0,1,\\ldots, called rounds.

We consistently use superscripts to indicate rounds. To indicate that a non-numerical quantity QQ (e.g., a string, a public key, a set, a digital signature, etc.) refers to a round rr, we simply write QrQ^{r}. Only when QQ is a genuine number (as opposed to a binary string interpretable as a number), do we write Q(r)Q^{(r)}, so that the symbol rr could not be interpreted as the exponent of QQ.

At (the start of a) round r\>0r>0, the set of all public keys is P​KrPK^{r}, and the system status is

Sr\={(i,ai(r),…):i∈P​Kr},S^{r}=\\left\\{\\left(i,a\_{i}^{(r)},\\ldots\\right):i\\in PK^{r}\\right\\},

where ai(r)a\_{i}^{(r)} is the amount of money available to the public key ii. Note that P​KrPK^{r} is deducible from SrS^{r}, and that SrS^{r} may also specify other components for each public key ii.

For round 0, P​K0PK^{0} is the set of initial public keys, and S0S^{0} is the initial status. Both P​K0PK^{0} and S0S^{0} are assumed to be common knowledge in the system. For simplicity, at the start of round rr, so are P​K1,…,P​KrPK^{1},\\ldots,PK^{r} and S1,…,SrS^{1},\\ldots,S^{r}.

In a round rr, the system status transitions from SrS^{r} to Sr+1S^{r+1}: symbolically,

Round rr: Sr⟶Sr+1S^{r}\\longrightarrow S^{r+1}.

##### Payments

In Algorand, the users continually make payments (and disseminate them in the way described in subsection [2.7](#S2.SS7 "2.7 The Communication Model ‣ 2 Preliminaries ‣ ALGORAND")). A payment ℘\\wp of a user i∈P​Kri\\in PK^{r} has the same format and semantics as in the Ideal System. Namely,

℘\=S​I​Gi​(i,i′,a,I,H⁡(ℐ)).\\wp=SIG\_{i}(i,i^{\\prime},a,I,H({\\cal I}))\\kern 5.0pt.

Payment ℘\\wp is individually valid at a round rr (is a round-rr payment, for short) if (1) its amount aa is less than or equal to ai(r)a^{(r)}\_{i}, and (2) it does not appear in any official payset P​A​Yr′PAY^{r^{\\prime}} for r′<rr^{\\prime}<r. (As explained below, the second condition means that ℘\\wp has not already become effective.

A set of round-rr payments of ii is collectively valid if the sum of their amounts is at most ai(r)a^{(r)}\_{i}.

##### Paysets

A round-rr payset 𝒫{\\cal P} is a set of round-rr payments such that, for each user ii, the payments of ii in 𝒫{\\cal P} (possibly none) are collectively valid. The set of all round-rr paysets is ℙ​𝔸​𝕐​(r)\\mathbb{P}\\mathbb{A}\\mathbb{Y}(r). A round-rr payset 𝒫{\\cal P} is maximal if no superset of 𝒫{\\cal P} is a round-rr payset.

We actually suggest that a payment ℘\\wp also specifies a round ρ\\rho, ℘\=S​I​Gi​(ρ,i,i′,a,I,H⁡(ℐ))\\wp=SIG\_{i}(\\rho,i,i^{\\prime},a,I,H({\\cal I}))\\kern 5.0pt, and cannot be valid at any round outside \[ρ,ρ+k\]\[\\rho,\\rho+k\], for some fixed non-negative integer kk.44 4 This simplifies checking whether ℘\\wp has become “effective” (i.e., it simplifies determining whether some payset P​A​YrPAY^{r} contains ℘\\wp. When k\=0k=0, if ℘\=S​I​Gi​(r,i,i′,a,I,H⁡(ℐ))\\wp=SIG\_{i}(r,i,i^{\\prime},a,I,H({\\cal I}))\\kern 5.0pt, and ℘∉P​A​Yr\\wp\\notin PAY^{r}, then ii must re-submit ℘\\wp.

##### Official Paysets

For every round rr, Algorand publicly selects (in a manner described later on) a single (possibly empty) payset, P​A​YrPAY^{r}, the round’s official payset. (Essentially, P​A​YrPAY^{r} represents the round-rr payments that have “actually” happened.)

As in the Ideal System (and Bitcoin), (1) the only way for a new user jj to enter the system is to be the recipient of a payment belonging to the official payset P​A​YrPAY^{r} of a given round rr; and (2) P​A​YrPAY^{r} determines the status of the next round, Sr+1S^{r+1}, from that of the current round, SrS^{r}. Symbolically,

P​A​Yr:Sr⟶Sr+1PAY^{r}:S^{r}\\longrightarrow S^{r+1}.

Specifically,

-   1.
    
    the set of public keys of round r+1r+1, P​Kr+1PK^{r+1}, consists of the union of P​KrPK^{r} and the set of all payee keys that appear, for the first time, in the payments of P​A​YrPAY^{r}; and
    
-   2.
    
    the amount of money ai(r+1)a\_{i}^{(r+1)} that a user ii owns in round r+1r+1 is the sum of ai​(r)a\_{i}{(r)} —i.e., the amount of money ii owned in the previous round (0 if i∉P​Kri\\not\\in PK^{r})— and the sum of amounts paid to ii according to the payments of P​A​YrPAY^{r}.
    

In sum, as in the Ideal System, each status Sr+1S^{r+1} is deducible from the previous payment history:

P​A​Y0,…,P​A​YrPAY^{0},\\ldots,PAY^{r}.

### 2.4 Blocks and Proven Blocks

In Algorand0\\text{{Algorand}}\_{0}, the block BrB^{r} corresponding to a round rr specifies: rr itself; the set of payments of round rr, P​A​YrPAY^{r}; a quantity QrQ^{r}, to be explained, and the hash of the previous block, H⁡(Br−1)H(B^{r-1}). Thus, starting from some fixed block B0B^{0}, we have a traditional blockchain:

B1\=(1,PAY1,Q0,H(B0)),B2\=(2,PAY2,Q1,H(B1)),B3\=(3,PAY3,Q2,H(B2)),…B^{1}=(1,PAY^{1},Q^{0},H(B^{0})),\\quad B^{2}=(2,PAY^{2},Q^{1},H(B^{1})),\\quad B^{3}=(3,PAY^{3},Q^{2},H(B^{2})),\\quad\\ldots

In Algorand, the authenticity of a block is actually vouched by a separate piece of information, a “block certificate” C​E​R​TrCERT^{r}, which turns BrB^{r} into a proven block, Br¯\\overline{B^{r}}. The Magic Ledger, therefore, is implemented by the sequence of the proven blocks,

B1¯,B2¯,…\\overline{B^{1}},\\overline{B^{2}},\\ldots

##### Discussion

As we shall see, C​E​R​TrCERT^{r} consists of a set of digital signatures for H⁡(Br)H(B^{r}), those of a majority of the members of S​VrSV^{r}, together with a proof that each of those members indeed belongs to S​VrSV^{r}. We could, of course, include the certificates C​E​R​TrCERT^{r} in the blocks themselves, but find it conceptually cleaner to keep it separate.)

In Bitcoin each block must satisfy a special property, that is, must “contain a solution of a crypto puzzle”, which makes block generation computationally intensive and forks both inevitable and not rare. By contrast, Algorand’s blockchain has two main advantages: it is generated with minimal computation, and it will not fork with overwhelmingly high probability. Each block BiB^{i} is safely final as soon as it enters the blockchain.

### 2.5 Acceptable Failure Probability

To analyze the security of Algorand we specify the probability, FF, with which we are willing to accept that something goes wrong (e.g., that a verifier set S​VrSV^{r} does not have an honest majority). As in the case of the output length of the cryptographic hash function HH, also FF is a parameter. But, as in that case, we find it useful to set FF to a concrete value, so as to get a more intuitive grasp of the fact that it is indeed possible, in Algorand, to enjoy simultaneously sufficient security and sufficient efficiency. To emphasize that FF is parameter that can be set as desired, in the first and second embodiments we respectively set

F\=10−12andF\=10−18.F=10^{-12}\\quad\\text{and}\\quad F=10^{-18}\\kern 5.0pt.

##### Discussion

Note that 10−1210^{-12} is actually less than one in a trillion, and we believe that such a choice of FF is adequate in our application. Let us emphasize that 10−1210^{-12} is not the probability with which the Adversary can forge the payments of an honest user. All payments are digitally signed, and thus, if the proper digital signatures are used, the probability of forging a payment is far lower than 10−1210^{-12}, and is, in fact, essentially 0. The bad event that we are willing to tolerate with probability FF is that Algorand’s blockchain forks. Notice that, with our setting of FF and one-minute long rounds, a fork is expected to occur in Algorand’s blockchain as infrequently as (roughly) once in 1.9 million years. By contrast, in Bitcoin, a forks occurs quite often.

A more demanding person may set FF to a lower value. To this end, in our second embodiment we consider setting FF to 10−1810^{-18}. Note that, assuming that a block is generated every second, 101810^{18} is the estimated number of seconds taken by the Universe so far: from the Big Bang to present time. Thus, with F\=10−18F=10^{-18}, if a block is generated in a second, one should expect for the age of the Universe to see a fork.

### 2.6 The Adversarial Model

Algorand is designed to be secure in a very adversarial model. Let us explain.

##### Honest and Malicious Users

A user is honest if he follows all his protocol instructions, and is perfectly capable of sending and receiving messages. A user is malicious (i.e., Byzantine, in the parlance of distributed computing) if he can deviate arbitrarily from his prescribed instructions.

##### The Adversary

The Adversary is an efficient (technically polynomial-time) algorithm, personified for color, who can immediately make malicious any user he wants, at any time he wants (subject only to an upperbound to the number of the users he can corrupt).

The Adversary totally controls and perfectly coordinates all malicious users. He takes all actions on their behalf, including receiving and sending all their messages, and can let them deviate from their prescribed instructions in arbitrary ways. Or he can simply isolate a corrupted user sending and receiving messages. Let us clarify that no one else automatically learns that a user ii is malicious, although ii’s maliciousness may transpire by the actions the Adversary has him take.

This powerful adversary however,

-   •
    
    Does not have unbounded computational power and cannot successfully forge the digital signature of an honest user, except with negligible probability; and
    
-   •
    
    Cannot interfere in any way with the messages exchanges among honest users.
    

Furthermore, his ability to attack honest users is bounded by one of the following assumption.

##### Honesty Majority of Money

We consider a continuum of Honest Majority of Money (HMM) assumptions: namely, for each non-negative integer kk and real h\>1/2h>1/2,

-   H​H​Mk\>hHHM\_{k}>h: the honest users in every round rr owned a fraction greater than hh of all money in the system at round r−kr-k.
    

##### Discussion.

Assuming that all malicious users perfectly coordinate their actions (as if controlled by a single entity, the Adversary) is a rather pessimistic hypothesis. Perfect coordination among too many individuals is difficult to achieve. Perhaps coordination only occurs within separate groups of malicious players. But, since one cannot be sure about the level of coordination malicious users may enjoy, we’d better be safe than sorry.

Assuming that the Adversary can secretly, dynamically, and immediately corrupt users is also pessimistic. After all, realistically, taking full control of a user’s operations should take some time.

The assumption H​M​Mk\>hHMM\_{k}>h implies, for instance, that, if a round (on average) is implemented in one minute, then, the majority of the money at a given round will remain in honest hands for at least two hours, if k\=120k=120, and at least one week, if k\=10,000k=10,000.

Note that the HMM assumptions and the previous Honest Majority of Computing Power assumptions are related in the sense that, since computing power can be bought with money, if malicious users own most of the money, then they can obtain most of the computing power.

### 2.7 The Communication Model

We envisage message propagation ---i.e., ‘‘peer-to-peer gossip’’55 5 Essentially, as in Bitcoin, when a user propagates a message mm, every active user ii receiving mm for the first time, randomly and independently selects a suitably small number of active users, his “neighbors”, to whom he forwards mm, possibly until he receives an acknowledgement from them. The propagation of mm terminates when no user receives mm for the first time.— to be the only means of communication.

##### Temporary Assumption: Timely Delivery of Messages in the Entire Network.

For most part of this paper we assume that every propagated message reaches almost all honest users in a timely fashion. We shall remove this assumption in Section [10](#S10 "10 Handling Network Partitions ‣ ALGORAND"), where we deal with network partitions, either naturally occurring or adversarially induced. (As we shall see, we only assume timely delivery of messages within each connected component of the network.)

One concrete way to capture timely delivery of propagated messages (in the entire network) is the following:

-   For all reachability ρ\>95%\\rho>95\\% and message size μ∈ℤ+\\mu\\in\\mathbb{Z}\_{+}, there exists λρ,μ\\lambda\_{\\rho,\\mu} such that,
    
    if a honest user propagates μ\\mu\-byte message mm at time tt,
    
    then mm reaches, by time t+λρ,μt+\\lambda\_{\\rho,\\mu}, at least a fraction ρ\\rho of the honest users.
    

The above property, however, cannot support our Algorand protocol, without explicitly and separately envisaging a mechanism to obtain the latest blockchain —by another user/depository/etc. In fact, to construct a new block BrB^{r} not only should a proper set of verifiers timely receive round-rr messages, but also the messages of previous rounds, so as to know Br−1B^{r-1} and all other previous blocks, which is necessary to determine whether the payments in BrB^{r} are valid. The following assumption instead suffices.

##### Message Propagation (MP) Assumption:

For all ρ\>95%\\rho>95\\% and μ∈ℤ+\\mu\\in\\mathbb{Z}\_{+}, there exists λρ,μ\\lambda\_{\\rho,\\mu} such that, for all times tt and all μ\\mu\-byte messages mm propagated by an honest user before t−λρ,μt-\\lambda\_{\\rho,\\mu}, mm is received, by time tt, by at least a fraction ρ\\rho of the honest users.

Protocol Algorand′\\text{{Algorand}}\\,^{\\prime} actually instructs each of a small number of users (i.e., the verifiers of a given step of a round in Algorand′\\text{{Algorand}}\\,^{\\prime}, to propagate a separate message of a (small) prescribed size, and we need to bound the time required to fulfill these instructions. We do so by enriching the MP assumption as follows.

For all nn, ρ\>95%\\rho>95\\%, and μ∈ℤ+\\mu\\in\\mathbb{Z}\_{+}, there exists λn,ρ,μ\\lambda\_{n,\\rho,\\mu} such that, for all times tt and all μ\\mu\-byte messages m1,…,mnm\_{1},\\ldots,m\_{n}, each propagated by an honest user before t−λn,ρ,μt-\\lambda\_{n,\\rho,\\mu}, m1,…,mnm\_{1},\\ldots,m\_{n} are received, by time tt, by at least a fraction ρ\\rho of the honest users.

##### Note

-   •
    
    The above assumption is deliberately simple, but also stronger than needed in our paper.66 6 Given the honest percentage hh and the acceptable failure probability FF, Algorand computes an upperbound, NN, to the maximum number of member of verifiers in a step. Thus, the MP assumption need only hold for n≤Nn\\leq N. In addition, as stated, the MP assumption holds no matter how many other messages may be propagated alongside the mjm\_{j}’s. As we shall see, however, in Algorand messages at are propagated in essentially non-overlapping time intervals, during which either a single block is propagated, or at most NN verifiers propagate a small (e.g., 200B) message. Thus, we could restate the MP assumption in a weaker, but also more complex, way.
    
-   •
    
    For simplicity, we assume ρ\=1\\rho=1, and thus drop mentioning ρ\\rho.
    
-   •
    
    We pessimistically assume that, provided he does not violate the MP assumption, the Adversary totally controls the delivery of all messages. In particular, without being noticed by the honest users, the Adversary he can arbitrarily decide which honest player receives which message when, and arbitrarily accelerate the delivery of any message he wants.77 7 For instance, he can immediately learn the messages sent by honest players. Thus, a malicious user i′i^{\\prime}, who is asked to propagate a message simultaneously with a honest user ii, can always choose his own message m′m^{\\prime} based on the message mm actually propagated by ii. This ability is related to rushing, in the parlance of distributed-computation literature.
    

## 3 The BA Protocol 𝑩​𝑨⋆\\bm{BA^{\\star}} in a Traditional Setting

As already emphasized, Byzantine agreement is a key ingredient of Algorand. Indeed, it is through the use of such a BA protocol that Algorand is unaffected by forks. However, to be secure against our powerful Adversary, Algorand must rely on a BA protocol that satisfies the new player-replaceability constraint. In addition, for Algorand to be efficient, such a BA protocol must be very efficient.

BA protocols were first defined for an idealized communication model, synchronous complete networks (SC networks). Such a model allows for a simpler design and analysis of BA protocols. Accordingly, in this section, we introduce a new BA protocol, B​A⋆BA^{\\star}, for SC networks and ignoring the issue of player replaceability altogether. The protocol B​A⋆BA^{\\star} is a contribution of separate value. Indeed, it is the most efficient cryptographic BA protocol for SC networks known so far.

To use it within our Algorand protocol, we modify B​A⋆BA^{\\star} a bit, so as to account for our different communication model and context, but make sure, in section X, to highlight how B​A⋆BA^{\\star} is used within our actual protocol Algorand′\\text{{Algorand}}\\,^{\\prime}.

We start by recalling the model in which B​A⋆BA^{\\star} operates and the notion of a Byzantine agreement.

### 3.1 Synchronous Complete Networks and Matching Adversaries

In a SC network, there is a common clock, ticking at each integral times r\=1,2,…r=1,2,\\ldots

At each even time click rr, each player ii instantaneously and simultaneously sends a single message mi,jrm\_{i,j}^{r} (possibly the empty message) to each player jj, including himself. Each mi,jrm\_{i,j}^{r} is received at time click r+1r+1 by player jj, together with the identity of the sender ii.

Again, in a communication protocol, a player is honest if he follows all his prescribed instructions, and malicious otherwise. All malicious players are totally controlled and perfectly coordinated by the Adversary, who, in particular, immediately receives all messages addressed to malicious players, and chooses the messages they send.

The Adversary can immediately make malicious any honest user he wants at any odd time click he wants, subject only to a possible upperbound tt to the number of malicious players. That is, the Adversary “cannot interfere with the messages already sent by an honest user ii”, which will be delivered as usual.

The Adversary also has the additional ability to see instantaneously, at each even round, the messages that the currently honest players send, and instantaneously use this information to choose the messages the malicious players send at the same time tick.

##### Remarks

-   •
    
    Adversary Power. The above setting is very adversarial. Indeed, in the Byzantine agreement literature, many settings are less adversarial. However, some more adversarial settings have also been considered, where the Adversary, after seeing the messages sent by an honest player ii at a given time click rr, has the ability to erase all these messages from the network, immediately corrupt ii, choose the message that the now malicious ii sends at time click rr, and have them delivered as usual. The envisaged power of the Adversary matches that he has in our setting.
    
-   •
    
    Physical Abstraction. The envisaged communication model abstracts a more physical model, in which each pair of players (i,j)(i,j) is linked by a separate and private communication line li,jl\_{i,j}. That is, no one else can inject, interfere with, or gain information about the messages sent over li,jl\_{i,j}. The only way for the Adversary to have access to li,jl\_{i,j} is to corrupt either ii or jj.
    
-   •
    
    Privacy and Authentication. In SC networks message privacy and authentication are guaranteed by assumption. By contrast, in our communication network, where messages are propagated from peer to peer, authentication is guaranteed by digital signatures, and privacy is non-existent. Thus, to adopt protocol B​A⋆BA^{\\star} to our setting, each message exchanged should be digitally signed (further identifying the state at which it was sent). Fortunately, the BA protocols that we consider using in Algorand do not require message privacy.
    

### 3.2 The Notion of a Byzantine Agreement

The notion of Byzantine agreement was introduced by Pease Shostak and Lamport \[[31](#bib.bib31)\] for the binary case, that is, when every initial value consists of a bit. However, it was quickly extended to arbitrary initial values. (See the surveys of Fischer \[[16](#bib.bib16)\] and Chor and Dwork \[[10](#bib.bib10)\].) By a BA protocol, we mean an arbitrary-value one.

###### Definition 3.1.

In a synchronous network, let 𝒫{\\cal P} be a nn\-player protocol, whose player set is common knowledge among the players, tt a positive integer such that n≥2​t+1n\\geq 2t+1. We say that 𝒫{\\cal P} is an arbitrary-value (respectively, binary) (n,t)(n,t)\-Byzantine agreement protocol with soundness σ∈(0,1)\\sigma\\in(0,1) if, for every set of values VV not containing the special symbol ⊥\\bot (respectively, for V\={0,1}V=\\{0,1\\}), in an execution in which at most tt of the players are malicious and in which every player ii starts with an initial value vi∈Vv\_{i}\\in V, every honest player jj halts with probability 1, outputting a value o​u​ti∈V∪{⊥}out\_{i}\\in V\\cup\\{\\bot\\} so as to satisfy, with probability at least σ\\sigma, the following two conditions:

-   1.
    
    Agreement: There exists o​u​t∈V∪{⊥}out\\in V\\cup\\{\\bot\\} such that o​u​ti\=o​u​tout\_{i}=out for all honest players ii.
    
-   2.
    
    Consistency: if, for some value v∈Vv\\in V, vi\=vv\_{i}=v for all honest players, then o​u​t\=vout=v.
    

We refer to o​u​tout as 𝒫{\\cal P}’s output, and to each o​u​tiout\_{i} as player ii’s output.

### 3.3 The BA Notation #\\bm{\\#}

In our BA protocols, a player is required to count how many players sent him a given message in a given step. Accordingly, for each possible value vv that might be sent,

#is​(v)\\#^{s}\_{i}(v)

(or just #i​(v)\\#\_{i}(v) when ss is clear) is the number of players jj from which ii has received vv in step ss.

Recalling that a player ii receives exactly one message from each player jj, if the number of players is nn, then, for all ii and ss, ∑v#is​(v)\=n.\\sum\_{v}\\#\_{i}^{s}(v)=n.

### 3.4 The Binary BA Protocol 𝑩​𝑩​𝑨⋆\\bm{BBA^{\\star}}

In this section we present a new binary BA protocol, B​B​A⋆BBA^{\\star}, which relies on the honesty of more than two thirds of the players and is very fast: no matter what the malicious players might do, each execution of its main loop brings the players into agreement with probability 1/3.

Each player has his own public key of a digital signature scheme satisfying the unique-signature property. Since this protocol is intended to be run on synchronous complete network, there is no need for a player ii to sign each of his messages.

Digital signatures are used to generate a sufficiently common random bit in Step 3. (In Algorand, digital signatures are used to authenticate all other messages as well.)

The protocol requires a minimal set-up: a common random string rr, independent of the players’ keys. (In Algorand, rr is actually replaced by the quantity QrQ^{r}.)

Protocol B​B​A⋆BBA^{\\star} is a 3-step loop, where the players repeatedly exchange Boolean values, and different players may exit this loop at different times. A player ii exits this loop by propagating, at some step, either a special value 0∗0\* or a special value 1∗1\*, thereby instructing all players to “pretend” they respectively receive 0 and 1 from ii in all future steps. (Alternatively said: assume that the last message received by a player jj from another player ii was a bit bb. Then, in any step in which he does not receive any message from ii, jj acts as if ii sent him the bit bb.)

The protocol uses a counter γ\\gamma, representing how many times its 3-step loop has been executed. At the start of B​B​A⋆BBA^{\\star}, γ\=0\\gamma=0. (One may think of γ\\gamma as a global counter, but it is actually increased by each individual player every time that the loop is executed.)

There are n≥3​t+1n\\geq 3t+1, where tt is the maximum possible number of malicious players. A binary string xx is identified with the integer whose binary representation (with possible leadings 0s) is xx; and 𝚕𝚜𝚋⁡(x){\\tt lsb}(x) denotes the least significant bit of xx.

Protocol B​B​A⋆BBA^{\\star}

(Communication) Step 1.

\[Coin-Fixed-To-0 Step\] Each player ii sends bib\_{i}.

-   1.1
    
    If #i1​(0)≥2​t+1\\#^{1}\_{i}(0)\\geq 2t+1, then ii sets bi\=0b\_{i}=0,  sends 0∗0\*,  outputs o​u​ti\=0out\_{i}=0,   and HALTS.
    
-   1.2
    
    If #i1​(1)≥2​t+1\\#^{1}\_{i}(1)\\geq 2t+1, then, then ii sets bi\=1b\_{i}=1.
    
-   1.3
    
    Else, ii sets bi\=0b\_{i}=0.
    

(Communication) Step 2.

\[Coin-Fixed-To-1 Step\] Each player ii sends bib\_{i}.

-   2.1
    
    If #i2​(1)≥2​t+1\\#^{2}\_{i}(1)\\geq 2t+1, then ii sets bi\=1b\_{i}=1,   sends 1∗1\*,   outputs o​u​ti\=1out\_{i}=1,   and HALTS.
    
-   2.2
    
    If #i2​(0)≥2​t+1\\#^{2}\_{i}(0)\\geq 2t+1, then ii set bi\=0b\_{i}=0.
    
-   2.3
    
    Else, ii sets bi\=1b\_{i}=1.
    

(Communication) Step 3.

\[Coin-Genuinely-Flipped Step\] Each player ii sends bib\_{i} and S​I​Gi​(r,γ)SIG\_{i}(r,\\gamma).

-   3.1
    
    If #i3​(0)≥2​t+1\\#^{3}\_{i}(0)\\geq 2t+1, then ii sets bi\=0b\_{i}=0.
    
-   3.2
    
    If #i3​(1)≥2​t+1\\#^{3}\_{i}(1)\\geq 2t+1, then ii sets bi\=1b\_{i}=1.
    
-   3.3
    
    Else, letting Si\={j∈N who have sent i a proper message in this step 3 }S\_{i}=\\{j\\in N\\text{ who have sent $i$ a proper message in this step 3 }\\},  
    ii sets bi\=c≜𝚕𝚜𝚋⁡(minj∈Si⁡H⁡(SIGi​(r,γ)))b\_{i}=c\\triangleq\\lsb(\\min\_{j\\in S\_{i}}H(SIG\_{i}(r,\\gamma)));  increases γi\\gamma\_{i} by 1;  and returns to Step 1.
    

###### Theorem 3.1.

Whenever n≥3​t+1n\\geq 3t+1, B​B​A⋆BBA^{\\star} is a binary (n,t)(n,t)\-BA protocol with soundness 1.

A proof of Theorem [3.1](#S3.Thmtheorem1 "Theorem 3.1. ‣ 3.4 The Binary BA Protocol 𝑩⁢𝑩⁢𝑨^⋆ ‣ 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND") is given in \[[26](#bib.bib26)\]. Its adaptation to our setting, and its player-replaceability property are novel.

##### Historical Remark

Probabilistic binary BA protocols were first proposed by Ben-Or in asynchronous settings \[[7](#bib.bib7)\]. Protocol B​B​A⋆BBA^{\\star} is a novel adaptation, to our public-key setting, of the binary BA protocol of Feldman and Micali \[[15](#bib.bib15)\]. Their protocol was the first to work in an expected constant number of steps. It worked by having the players themselves implement a common coin, a notion proposed by Rabin, who implemented it via an external trusted party \[[32](#bib.bib32)\].

### 3.5 Graded Consensus and the Protocol 𝑮​𝑪{{\\bm{GC$}}}

Letusrecall,forarbitraryvalues,anotionofconsensusmuchweakerthanByzantineagreement.

###### Definition 3.2.

Let 𝒫{\\cal P} be a protocol in which the set of all players is common knowledge, and each player ii privately knows an arbitrary initial value vi′v\_{i}^{\\prime}.

We say that 𝒫{\\cal P} is an (n,t)(n,t)\-graded consensus protocol if, in every execution with nn players, at most tt of which are malicious, every honest player ii halts outputting a value-grade pair (vi,gi)(v\_{i},g\_{i}), where gi∈{0,1,2}g\_{i}\\in\\{0,1,2\\}, so as to satisfy the following three conditions:

-   1.
    
    For all honest players ii and jj, |gi−gj|≤1|g\_{i}-g\_{j}|\\leq 1.
    
-   2.
    
    For all honest players ii and jj, gi,gj\>0⇒vi\=vjg\_{i},g\_{j}>0\\Rightarrow v\_{i}=v\_{j}.
    
-   3.
    
    If v1′\=⋯\=vn′\=vv\_{1}^{\\prime}=\\cdots=v\_{n}^{\\prime}=v for some value vv, then vi\=vv\_{i}=v and gi\=2g\_{i}=2 for all honest players ii.
    

##### Historical Note

The notion of a graded consensus is simply derived from that of a graded broadcast, put forward by Feldman and Micali in \[[15](#bib.bib15)\], by strengthening the notion of a crusader agreement, as introduced by Dolev \[[12](#bib.bib12)\], and refined by Turpin and Coan \[[33](#bib.bib33)\].88 8 In essence, in a graded-broadcasting protocol, (a) the input of every player is the identity of a distinguished player, the sender, who has an arbitrary value vv as an additional private input, and (b) the outputs must satisfy the same properties 1 and 2 of graded consensus, plus the following property 3′3^{\\prime}: if the sender is honest, then vi\=vv\_{i}=v and gi\=2g\_{i}=2 for all honest player ii.

In \[[15](#bib.bib15)\], the authors also provided a 3-step (n,t)(n,t)\-graded broadcasting protocol, gradecast, for n≥3​t+1n\\geq 3t+1. A more complex (n,t)(n,t)\-graded-broadcasting protocol for n\>2​t+1n>2t+1 has later been found by Katz and Koo \[[19](#bib.bib19)\].

The following two-step protocol G​CGC consists of the last two steps of gradecast, expressed in our notation. To emphasize this fact, and to match the steps of protocol Algorand′\\text{{Algorand}}\\,^{\\prime} of section [4.1](#S4.SS1 "4.1 A Common Core ‣ 4 Two Embodiments of Algorand ‣ ALGORAND"), we respectively name 2 and 3 the steps of G​CGC.

Protocol G​CGC

Step 2.

Each player ii sends vi′v\_{i}^{\\prime} to all players.

Step 3.

Each player ii sends to all players the string xx if and only if #i2​(x)≥2​t+1\\#\_{i}^{2}(x)\\geq 2t+1.

Output Determination.

Each player ii outputs the pair (vi,gi)(v\_{i},g\_{i}) computed as follows:

-   •
    
    If, for some xx, #i3​(x)≥2​t+1\\#\_{i}^{3}(x)\\geq 2t+1, then vi\=xv\_{i}=x and gi\=2g\_{i}=2.
    
-   •
    
    If, for some xx, #i3​(x)≥t+1\\#\_{i}^{3}(x)\\geq t+1, then vi\=xv\_{i}=x and gi\=1g\_{i}=1.
    
-   •
    
    Else, vi\=⊥v\_{i}=\\bot and gi\=0g\_{i}=0.
    

###### Theorem 3.2.

If n≥3​t+1n\\geq 3t+1, then G​CGC is a (n,t)(n,t)\-graded broadcast protocol.

The proof immediately follows from that of the protocol gradecast in \[[15](#bib.bib15)\], and is thus omitted.99 9 Indeed, in their protocol, in step 1, the sender sends his own private value vv to all players, and each player ii lets vi′v\_{i}^{\\prime} consist of the value he has actually received from the sender in step 1.

### 3.6 The Protocol 𝑩​𝑨⋆\\bm{BA^{\\star}}

We now describe the arbitrary-value BA protocol B​A⋆BA^{\\star} via the binary BA protocol B​B​A⋆BBA^{\\star} and the graded-consensus protocol G​CGC. Below, the initial value of each player ii is vi′v\_{i}^{\\prime}.

Protocol B​A⋆BA^{\\star}

Steps 1 and 2.

Each player ii executes G​CGC, on input vi′v\_{i}^{\\prime}, so as to compute a pair (vi,gi)(v\_{i},g\_{i}).

Step 3, …\\ldots

Each player ii executes B​B​A⋆BBA^{\\star} —with initial input 0, if gi\=2g\_{i}=2, and 1 otherwise— so as to compute the bit o​u​tiout\_{i}.

Output Determination.

Each player ii outputs viv\_{i}, if o​u​ti\=0out\_{i}=0, and ⊥\\bot otherwise.

###### Theorem 3.3.

Whenever n≥3​t+1n\\geq 3t+1, B​A⋆BA^{\\star} is a (n,t)(n,t)\-BA protocol with soundness 1.

Proof. We first prove Consistency, and then Agreement.

Proof of Consistency. Assume that, for some value v∈Vv\\in V, vi′\=vv\_{i}^{\\prime}=v. Then, by property 3 of graded consensus, after the execution of G​CGC, all honest players output (v,2)(v,2). Accordingly, 0 is the initial bit of all honest players in the end of the execution of B​B​A⋆BBA^{\\star}. Thus, by the Agreement property of binary Byzantine agreement, at the end of the execution of B​A⋆BA^{\\star}, o​u​ti\=0out\_{i}=0 for all honest players. This implies that the output of each honest player ii in B​A⋆BA^{\\star} is vi\=vv\_{i}=v.  □\\Box

Proof of Agreement. Since B​B​A⋆BBA^{\\star} is a binary BA protocol, either

(A) o​u​ti\=1out\_{i}=1 for all honest player ii, or

(B) o​u​ti\=0out\_{i}=0 for all honest player ii.

In case A, all honest players output ⊥\\bot in B​A⋆BA^{\\star}, and thus Agreement holds. Consider now case B. In this case, in the execution of B​B​A⋆BBA^{\\star}, the initial bit of at least one honest player ii is 0. (Indeed, if initial bit of all honest players were 1, then, by the Consistency property of B​B​A⋆BBA^{\\star}, we would have o​u​tj\=1out\_{j}=1 for all honest jj.) Accordingly, after the execution of G​CGC, ii outputs the pair (v,2)(v,2) for some value vv. Thus, by property 1 of graded consensus, gj\>0g\_{j}>0 for all honest players jj. Accordingly, by property 2 of graded consensus, vj\=vv\_{j}=v for all honest players jj. This implies that, at the end of B​A⋆BA^{\\star}, every honest player jj outputs vv. Thus, Agreement holds also in case B.  □\\Box

Since both Consistency and Agreement hold, B​A⋆BA^{\\star} is an arbitrary-value BA protocol.     

##### Historical Note

Turpin and Coan were the first to show that, for n≥3​t+1n\\geq 3t+1, any binary (n,t)(n,t)\-BA protocol can be converted to an arbitrary-value (n,t)(n,t)\-BA protocol. The reduction arbitrary-value Byzantine agreement to binary Byzantine agreement via graded consensus is more modular and cleaner, and simplifies the analysis of our Algorand protocol Algorand′\\text{{Algorand}}\\,^{\\prime}.

##### Generalizing 𝑩​𝑨⋆\\bm{BA^{\\star}} for use in Algorand

Algorand works even when all communication is via gossiping. However, although presented in a traditional and familiar communication network, so as to enable a better comparison with the prior art and an easier understanding, protocol B​A⋆BA^{\\star} works also in gossiping networks. In fact, in our detailed embodiments of Algorand, we shall present it directly for gossiping networks. We shall also point out that it satisfies the player replaceability property that is crucial for Algorand to be secure in the envisaged very adversarial model.

Any BA player-replaceable protocol working in a gossiping communication network can be securely employed within the inventive Algorand system. In particular, Micali and Vaikunthanatan have extended B​A⋆BA^{\\star} to work very efficiently also with a simple majority of honest players. That protocol too could be used in Algorand.

## 4 Two Embodiments of Algorand

As discussed, at a very high level, a round of Algorand ideally proceeds as follows. First, a randomly selected user, the leader, proposes and circulates a new block. (This process includes initially selecting a few potential leaders and then ensuring that, at least a good fraction of the time, a single common leader emerges.) Second, a randomly selected committee of users is selected, and reaches Byzantine agreement on the block proposed by the leader. (This process includes that each step of the BA protocol is run by a separately selected committee.) The agreed upon block is then digitally signed by a given threshold (THT\_{H}) of committee members. These digital signatures are circulated so that everyone is assured of which is the new block. (This includes circulating the credential of the signers, and authenticating just the hash of the new block, ensuring that everyone is guaranteed to learn the block, once its hash is made clear.)

In the next two sections, we present two embodiments of Algorand, Algorand1′{\\text{{Algorand}}\\,^{\\prime}\_{1}} and Algorand2′{\\text{{Algorand}}\\,^{\\prime}\_{2}}, that work under a majority-of-honest-users assumption. In Section [8](#S8 "8 Protocol \"Algorand\"^′ with Honest Majority of Money ‣ ALGORAND") we show how to adopts these embodiments to work under a honest-majority-of-money assumption.

Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1} only envisages that \>2/3\>2/3 of the committee members are honest. In addition, in Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1}, the number of steps for reaching Byzantine agreement is capped at a suitably high number, so that agreement is guaranteed to be reached with overwhelming probability within a fixed number of steps (but potentially requiring longer time than the steps of Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2}). In the remote case in which agreement is not yet reached by the last step, the committee agrees on the empty block, which is always valid.

Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2} envisages that the number of honest members in a committee is always greater than or equal to a fixed threshold tHt\_{H} (which guarantees that, with overwhelming probability, at least 2/3 of the committee members are honest). In addition, Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2} allows Byzantine agreement to be reached in an arbitrary number of steps (but potentially in a shorter time than Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1}).

It is easy to derive many variants of these basic embodiments. In particular, it is easy, given Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2}, to modify Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1} so as to enable to reach Byzantine agreement in an arbitrary number of steps.

Both embodiments share the following common core, notations, notions, and parameters.

### 4.1 A Common Core

##### Objectives

Ideally, for each round rr, Algorand would satisfy the following properties:

1.  1.
    
    Perfect Correctness. All honest users agree on the same block BrB^{r}.
    
2.  2.
    
    Completeness 1. With probability 1, the payset of BrB^{r}, P​A​YrPAY^{r}, is maximal.1010 10 Because paysets are defined to contain valid payments, and honest users to make only valid payments, a maximal P​A​YrPAY^{r} contains the “currently outstanding” payments of all honest users.
    

Of course, guaranteeing perfect correctness alone is trivial: everyone always chooses the official payset P​A​YrPAY^{r} to be empty. But in this case, the system would have completeness 0. Unfortunately, guaranteeing both perfect correctness and completeness 1 is not easy in the presence of malicious users. Algorand thus adopts a more realistic objective. Informally, letting hh denote the percentage of users who are honest, h\>2/3h>2/3, the goal of Algorand is

Guaranteeing, with overwhelming probability, perfect correctness and completeness close to hh.

Privileging correctness over completeness seems a reasonable choice: payments not processed in one round can be processed in the next, but one should avoid forks, if possible.

##### Led Byzantine Agreement

Perfect Correctness could be guaranteed as follows. At the start of round rr, each user ii constructs his own candidate block BirB^{r}\_{i}, and then all users reach Byzantine agreement on one candidate block. As per our introduction, the BA protocol employed requires a 2/3 honest majority and is player replaceable. Each of its step can be executed by a small and randomly selected set of verifiers, who do not share any inner variables.

Unfortunately, this approach has no completeness guarantees. This is so, because the candidate blocks of the honest users are most likely totally different from each other. Thus, the ultimately agreed upon block might always be one with a non-maximal payset. In fact, it may always be the empty block, BεB\_{\\varepsilon}, that is, the block whose payset is empty. well be the default, empty one.

Algorand′\\text{{Algorand}}\\,^{\\prime} avoids this completeness problem as follows. First, a leader for round rr, ℓr\\ell^{r}, is selected. Then, ℓr\\ell^{r} propagates his own candidate block, BℓrrB^{r}\_{\\ell^{r}}. Finally, the users reach agreement on the block they actually receive from ℓr\\ell^{r}. Because, whenever ℓr\\ell^{r} is honest, Perfect Correctness and Completeness 1 both hold, Algorand′\\text{{Algorand}}\\,^{\\prime} ensures that ℓr\\ell^{r} is honest with probability close to hh. (When the leader is malicious, we do not care whether the agreed upon block is one with an empty payset. After all, a malicious leader ℓr\\ell^{r} might always maliciously choose BℓrrB^{r}\_{\\ell^{r}} to be the empty block, and then honestly propagate it, thus forcing the honest users to agree on the empty block.)

##### Leader Selection

In Algorand’s, the rrth block is of the form Br\=(r,P​A​Yr,Qr,H⁡(Br−1)CLOSEB^{r}=(r,PAY^{r},Q^{r},H(B^{r-1}). As already mentioned in the introduction, the quantity Qr−1Q^{r-1} is carefully constructed so as to be essentially non-manipulatable by our very powerful Adversary. (Later on in this section, we shall provide some intuition about why this is the case.) At the start of a round rr, all users know the blockchain so far, B0,…,Br−1B^{0},\\ldots,B^{r-1}, from which they deduce the set of users of every prior round: that is, P​K1,…,P​Kr−1PK^{1},\\ldots,PK^{r-1}. A potential leader of round rr is a user ii such that

.H(SIGi(r,1,Qr−1))≤p..H\\left(SIG\_{i}\\left(r,1,Q^{r-1}\\right)\\right)\\leq p\\kern 5.0pt.

Let us explain. Note that, since the quantity Qr−1Q^{r-1} is part of block Br−1B^{r-1}, and the underlying signature scheme satisfies the uniqueness property, S​I​Gi​(r,1,Qr−1)SIG\_{i}\\left(r,1,Q^{r-1}\\right) is a binary string uniquely associated to ii and rr. Thus, since HH is a random oracle, H⁡(S​I​Gi​(r,1,Qr−1))H\\left(SIG\_{i}\\left(r,1,Q^{r-1}\\right)\\right) is a random 256-bit long string uniquely associated to ii and rr. The symbol “.” in front of H⁡(S​I​Gi​(r,1,Qr−1))H\\left(SIG\_{i}\\left(r,1,Q^{r-1}\\right)\\right) is the decimal (in our case, binary) point, so that ri≜.H⁡(S​I​Gi​(r,1,Qr−1))r\_{i}\\triangleq.H\\left(SIG\_{i}\\left(r,1,Q^{r-1}\\right)\\right) is the binary expansion of a random 256-bit number between 0 and 1 uniquely associated to ii and rr. Thus the probability that rir\_{i} is less than or equal to pp is essentially pp. (Our potential-leader selection mechanism has been inspired by the micro-payment scheme of Micali and Rivest \[[28](#bib.bib28)\].)

The probability pp is chosen so that, with overwhelming (i.e., 1−F1-F) probability, at least one potential verifier is honest. (If fact, pp is chosen to be the smallest such probability.)

Note that, since ii is the only one capable of computing his own signatures, he alone can determine whether he is a potential verifier of round 1. However, by revealing his own credential, σir≜S​I​Gi​(r,1,Qr−1)\\sigma\_{i}^{r}\\triangleq SIG\_{i}\\left(r,1,Q^{r-1}\\right), ii can prove to anyone to be a potential verifier of round rr.

The leader ℓr\\ell^{r} is defined to be the potential leader whose hashed credential is smaller that the hashed credential of all other potential leader jj: that is, H⁡(σℓrr,s)≤H⁡(σjr,s)H(\\sigma\_{\\ell^{r}}^{r,s})\\leq H(\\sigma\_{j}^{r,s}).

Note that, since a malicious ℓr\\ell^{r} may not reveal his credential, the correct leader of round rr may never be known, and that, barring improbable ties, ℓr\\ell^{r} is indeed the only leader of round rr.

Let us finally bring up a last but important detail: a user ii can be a potential leader (and thus the leader) of a round rr only if he belonged to the system for at least kk rounds. This guarantees the non-manipulatability of QrQ^{r} and all future QQ\-quantities. In fact, one of the potential leaders will actually determine QrQ^{r}.

##### Verifier Selection

Each step s\>1s>1 of round rr is executed by a small set of verifiers, S​Vr,sSV^{r,s}. Again, each verifier i∈S​Vr,si\\in SV^{r,s} is randomly selected among the users already in the system kk rounds before rr, and again via the special quantity Qr−1Q^{r-1}. Specifically, i∈P​Kr−ki\\in PK^{r-k} is a verifier in S​Vr,sSV^{r,s}, if

.H(SIGi(r,s,Qr−1))≤p′..H\\left(SIG\_{i}\\left(r,s,Q^{r-1}\\right)\\right)\\leq p^{\\prime}\\kern 5.0pt.

Once more, only ii knows whether he belongs to S​Vr,sSV^{r,s},but, if this is the case, he could prove it by exhibiting his credential σir,s≜H⁡(S​I​Gi​(r,s,Qr−1))\\sigma\_{i}^{r,s}\\triangleq H(SIG\_{i}\\left(r,s,Q^{r-1}\\right)). A verifier i∈S​Vr,si\\in SV^{r,s} sends a message, mir,sm\_{i}^{r,s}, in step ss of round rr, and this message includes his credential σir,s\\sigma\_{i}^{r,s}, so as to enable the verifiers f the nest step to recognize that mir,sm\_{i}^{r,s} is a legitimate step-ss message.

The probability p′p^{\\prime} is chosen so as to ensure that, in S​Vr,sSV^{r,s}, letting #​g​o​o​d\\#good be the number of honest users and #​b​a​d\\#bad the number of malicious users, with overwhelming probability the following two conditions hold.

For embodiment Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1}:

(1) #​g​o​o​d\>2⋅#​b​a​d\\#good>2\\cdot\\#bad and

(2) #​g​o​o​d+4⋅#​b​a​d<2​n\\#good+4\\cdot\\#bad<2n, where nn is the expected cardinality of S​Vr,sSV^{r,s}.

For embodiment Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2}:

(1) #​g​o​o​d\>tH\\#good>t\_{H} and

(2) #​g​o​o​d+2​#​b​a​d<2​tH\\#good+2\\#bad<2t\_{H}, where tHt\_{H} is a specified threshold.

These conditions imply that, with sufficiently high probability, (a) in the last step of the BA protocol, there will be at least given number of honest players to digitally sign the new block BrB^{r}, (b) only one block per round may have the necessary number of signatures, and (c) the used BA protocol has (at each step) the required 2/3 honest majority.

##### Clarifying Block Generation

If the round-rr leader ℓr\\ell^{r} is honest, then the corresponding block is of the form

Br\=(r,P​A​Yr,S​I​Gℓr​(Qr−1),H⁡(Br−1)),B^{r}=\\left(r,PAY^{r},SIG\_{\\ell^{r}}\\left(Q^{r-1}\\right),H\\left(B^{r-1}\\right)\\right)\\kern 5.0pt,

where the payset P​A​YrPAY^{r} is maximal. (recall that all paysets are, by definition, collectively valid.)

Else (i.e., if ℓr\\ell^{r} is malicious), BrB^{r} has one of the following two possible forms:

Br\=(r,P​A​Yr,S​I​Gi​(Qr−1),H⁡(Br−1)) and Br\=Bεr≜(r,∅,Qr−1,H⁡(Br−1)).B^{r}=\\left(r,PAY^{r},SIG\_{i}\\left(Q^{r-1}\\right),H\\left(B^{r-1}\\right)\\right)\\quad\\text{ and }\\quad B^{r}=B\_{\\varepsilon}^{r}\\triangleq\\left(r,\\emptyset,Q^{r-1},H\\left(B^{r-1}\\right)\\right)\\kern 5.0pt.

In the first form, P​A​YrPAY^{r} is a (non-necessarily maximal) payset and it may be P​A​Yr\=∅PAY^{r}=\\emptyset; and ii is a potential leader of round rr. (However, ii may not be the leader ℓr\\ell^{r}. This may indeed happen if if ℓr\\ell^{r} keeps secret his credential and does not reveal himself.)

The second form arises when, in the round-rr execution of the BA protocol, all honest players output the default value, which is the empty block BεrB\_{\\varepsilon}^{r} in our application. (By definition, the possible outputs of a BA protocol include a default value, generically denoted by ⊥\\bot. See section [3.2](#S3.SS2 "3.2 The Notion of a Byzantine Agreement ‣ 3 The BA Protocol 𝑩⁢𝑨^⋆ in a Traditional Setting ‣ ALGORAND").)

Note that, although the paysets are empty in both cases, Br\=(r,∅,S​I​Gi​(Qr−1),H⁡(Br−1))B^{r}=\\left(r,\\emptyset,SIG\_{i}\\left(Q^{r-1}\\right),H\\left(B^{r-1}\\right)\\right) and BεrB\_{\\varepsilon}^{r} are syntactically different blocks and arise in two different situations: respectively, “all went smoothly enough in the execution of the BA protocol”, and “something went wrong in the BA protocol, and the default value was output”.

Let us now intuitively describe how the generation of block BrB^{r} proceeds in round rr of Algorand′\\text{{Algorand}}\\,^{\\prime}. In the first step, each eligible player, that is, each player i∈P​Kr−ki\\in PK^{r-k}, checks whether he is a potential leader. If this is the case, then ii is asked, using of all the payments he has seen so far, and the current blockchain, B0,…,Br−1B^{0},\\ldots,B^{r-1}, to secretly prepare a maximal payment set, P​A​YirPAY^{r}\_{i}, and secretly assembles his candidate block, Br\=(r,P​A​Yir,S​I​Gi​(Qr−1),H⁡(Br−1))B^{r}=\\left(r,PAY^{r}\_{i},SIG\_{i}\\left(Q^{r-1}\\right),H\\left(B^{r-1}\\right)\\right). That,is, not only does he include in BirB^{r}\_{i}, as its second component the just prepared payset, but also, as its third component, his own signature of Qr−1Q^{r-1}, the third component of the last block, Br−1B^{r-1}. Finally, he propagate his round-rr\-step-1 message, mir,1m\_{i}^{r,1}, which includes (a) his candidate block BirB^{r}\_{i}, (b) his proper signature of his candidate block (i.e., his signature of the hash of BirB^{r}\_{i}, and (c) his own credential σir,1\\sigma\_{i}^{r,1}, proving that he is indeed a potential verifier of round rr.

(Note that, until an honest ii produces his message mir,1m\_{i}^{r,1}, the Adversary has no clue that ii is a potential verifier. Should he wish to corrupt honest potential leaders, the Adversary might as well corrupt random honest players. However, once he sees mir,1m\_{i}^{r,1}, since it contains ii’s credential, the Adversary knows and could corrupt ii, but cannot prevent mir,1m\_{i}^{r,1}, which is virally propagated, from reaching all users in the system.)

In the second step, each selected verifier j∈S​Vr,2j\\in SV^{r,2} tries to identify the leader of the round. Specifically, jj takes the step-1 credentials, σi1r,1,…,σinr,1\\sigma\_{i\_{1}}^{r,1},\\ldots,\\sigma\_{i\_{n}}^{r,1}, contained in the proper step-1 message mir,1m\_{i}^{r,1} he has received; hashes all of them, that is, computes H⁡(σi1r,1),…,H⁡(σinr,1)H\\left(\\sigma\_{i\_{1}}^{r,1}\\right),\\ldots,H\\left(\\sigma\_{i\_{n}}^{r,1}\\right); finds the credential, σℓjr,1\\sigma\_{\\ell\_{j}}^{r,1}, whose hash is lexicographically minimum; and considers ℓjr\\ell\_{j}^{r} to be the leader of round rr.

Recall that each considered credential is a digital signature of Qr−1Q^{r-1}, that S​I​Gi​(r,1,Qr−1)SIG\_{i}\\left(r,1,Q^{r-1}\\right) is uniquely determined by ii and Qr−1Q^{r-1}, that HH is random oracle, and thus that each H⁡(S​I​Gi​(r,1,Qr−1)CLOSEH(SIG\_{i}\\left(r,1,Q^{r-1}\\right) is a random 256-bit long string unique to each potential leader ii of round rr.

From this we can conclude that, if the 256-bit string Qr−1Q^{r-1} were itself randomly and independently selected, than so would be the hashed credentials of all potential leaders of round rr. In fact, all potential leaders are well defined, and so are their credentials (whether actually computed or not). Further, the set of potential leaders of round rr is a random subset of the users of round r−kr-k, and an honest potential leader ii always properly constructs and propagates his message mirm\_{i}^{r}, which contains ii’s credential. Thus, since the percentage of honest users is hh, no matter what the malicious potential leaders might do (e.g., reveal or conceal their own credentials), the minimum hashed potential-leader credential belongs to a honest user, who is necessarily identified by everyone to be the leader ℓr\\ell^{r} of the round rr. Accordingly, if the 256-bit string Qr−1Q^{r-1} were itself randomly and independently selected, with probability exactly hh (a) the leader ℓr\\ell^{r} is honest and (b) ℓj\=ℓr\\ell\_{j}=\\ell^{r} for all honest step-2 verifiers jj.

In reality, the hashed credential are, yes, randomly selected, but depend on Qr−1Q^{r-1}, which is not randomly and independently selected. We shall prove in our analysis, however, that Qr−1Q^{r-1} is sufficiently non-manipulatable to guarantee that the leader of a round is honest with probability h′h^{\\prime} sufficiently close to hh: namely, h′\>h2​(1+h−h2)h^{\\prime}>h^{2}(1+h-h^{2}). For instance, if h\=80%h=80\\%, then h′\>.7424h^{\\prime}>.7424.

Having identified the leader of the round (which they correctly do when the leader ℓr\\ell^{r} is honest), the task of the step-2 verifiers is to start executing the BA using as initial values what they believe to be the block of the leader. Actually, in order to minimize the amount of communication required, a verifier j∈S​Vr,2j\\in SV^{r,2} does not use, as his input value vj′v\_{j}^{\\prime} to the Byzantine protocol, the block BjB\_{j} that he has actually received from ℓj\\ell\_{j} (the user jj believes to be the leader), but the the leader, but the hash of that block, that is, vj′\=H⁡(Bi)v\_{j}^{\\prime}=H(B\_{i}). Thus, upon termination of the BA protocol, the verifiers of the last step do not compute the desired round-rr block BrB^{r}, but compute (authenticate and propagate) H⁡(Br)H(B^{r}). Accordingly, since H⁡(Br)H(B^{r}) is digitally signed by sufficiently many verifiers of the last step of the BA protocol, the users in the system will realize that H⁡(Br)H(B^{r}) is the hash of the new block. However, they must also retrieve (or wait for, since the execution is quite asynchronous) the block BrB^{r} itself, which the protocol ensures that is indeed available, no matter what the Adversary might do.

##### Asynchrony and Timing

Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1} and Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2} have a significant degree of asynchrony. This is so because the Adversary has large latitude in scheduling the delivery of the messages being propagated. In addition, whether the total number of steps in a round is capped or not, there is the variance contribute by the number of steps actually taken.

As soon as he learns the certificates of B0,…,Br−1B^{0},\\ldots,B^{r-1}, a user ii computes Qr−1Q^{r-1} and starts working on round rr, checking whether he is a potential leader, or a verifier in some step ss of round rr.

Assuming that ii must act at step ss, in light of the discussed asynchrony, ii relies on various strategies to ensure that he has sufficient information before he acts.

For instance, he might wait to receive at least a given number of messages from the verifiers of the previous step, or wait for a sufficient time to ensure that he receives the messages of sufficiently many verifiers of the previous step.

##### The Seed 𝐐𝐫{\\mathbf{Q}}^{\\mathbf{r}} and the Look-Back Parameter 𝒌\\bm{k}

Recall that, ideally, the quantities QrQ^{r} should random and independent, although it will suffice for them to be sufficiently non-manipulatable by the Adversary.

At a first glance, we could choose Qr−1Q^{r-1} to coincide with H⁡(P​A​Yr−1)H\\left(PAY^{r-1}\\right), and thus avoid to specify Qr−1Q^{r-1} explicitly in Br−1B^{r-1}. An elementary analysis reveals, however, that malicious users may take advantage of this selection mechanism.1111 11 We are at the start of round r−1r-1. Thus, Qr−2\=P​A​Yr−2Q^{r-2}=PAY^{r-2} is publicly known, and the Adversary privately knows who are the potential leaders he controls. Assume that the Adversary controls 10% of the users, and that, with very high probability, a malicious user ww is the potential leader of round r−1r-1. That is, assume that H⁡(S​I​Gw​(r−2,1,Qr−2))H\\left(SIG\_{w}\\left(r-2,1,Q^{r-2}\\right)\\right) is so small that it is highly improbable an honest potential leader will actually be the leader of round r−1r-1. (Recall that, since we choose potential leaders via a secret cryptographic sortition mechanism, the Adversary does not know who the honest potential leaders are.) The Adversary, therefore, is in the enviable position of choosing the payset P​A​Y′PAY^{\\prime} he wants, and have it become the official payset of round r−1r-1. However, he can do more. He can also ensure that, with high probability, (\*) one of his malicious users will be the leader also of round rr, so that he can freely select what P​A​YrPAY^{r} will be. (And so on. At least for a long while, that is, as long as these high-probability events really occur.) To guarantee (\*), the Adversary acts as follows. Let P​A​Y′PAY^{\\prime} be the payset the Adversary prefers for round r−1r-1. Then, he computes H⁡(P​A​Y′)H(PAY^{\\prime}) and checks whether, for some already malicious player zz, S​I​Gz​(r,1,H⁡(P​A​Y′))SIG\_{z}(r,1,H(PAY^{\\prime})) is particularly small, that is, small enough that with very high probability zz will be the leader of round rr. If this is the case, then he instructs ww to choose his candidate block to be Bir−1\=(r−1,P​A​Y′,H⁡(Br−2)CLOSEB^{r-1}\_{i}=(r-1,PAY^{\\prime},H(B^{r-2}). Else, he has two other malicious users xx and yy to keep on generating a new payment ℘′\\wp^{\\prime}, from one to the other, until, for some malicious user zz (or even for some fixed user zz) H⁡(S​I​Gz​(P​A​Y′∪{℘}))H\\left(SIG\_{z}\\left(PAY^{\\prime}\\cup\\{\\wp\\}\\right)\\right) is particularly small too. This experiment will stop quite quickly. And when it does the Adversary asks ww to propose the candidate block Bir−1\=(r−1,P​A​Y′∪{℘},H⁡(Br−2)CLOSEB^{r-1}\_{i}=(r-1,PAY^{\\prime}\\cup\\{\\wp\\},H(B^{r-2}). Some additional effort shows that myriads of other alternatives, based on traditional block quantities are easily exploitable by the Adversary to ensure that malicious leaders are very frequent. We instead specifically and inductively define our brand new quantity QrQ^{r} so as to be able to prove that it is non-manipulatable by the Adversary. Namely,

Qr≜H⁡(S​I​Gℓr​(Qr−1),r), if Br is not the empty block, and ​Qr≜H⁡(Qr−1,r)​ otherwise.Q^{r}\\triangleq H(SIG\_{\\ell^{r}}(Q^{r-1}),r),\\text{ if $B^{r}$ is not the empty block, and }Q^{r}\\triangleq H(Q^{r-1},r)\\text{ otherwise.}

The intuition of why this construction of QrQ^{r} works is as follows. Assume for a moment that Qr−1Q^{r-1} is truly randomly and independently selected. Then, will so be QrQ^{r}? When ℓr\\ell^{r} is honest the answer is (roughly speaking) yes. This is so because

H⁡(S​I​Gℓr​(⋅),r):{0,1}256⟶{0,1}256H(SIG\_{\\ell^{r}}(\\cdot),r):\\{0,1\\}^{256}\\longrightarrow\\{0,1\\}^{256}

is a random function. When ℓr\\ell^{r} is malicious, however, QrQ^{r} is no longer univocally defined from Qr−1Q^{r-1} and ℓr\\ell^{r}. There are at least two separate values for QrQ^{r}. One continues to be Qr≜H⁡(S​I​Gℓr​(Qr−1),r)Q^{r}\\triangleq H(SIG\_{\\ell^{r}}(Q^{r-1}),r), and the other is H⁡(Qr−1,r)H(Q^{r-1},r). Let us first argue that, while the second choice is somewhat arbitrary, a second choice is absolutely mandatory. The reason for this is that a malicious ℓr\\ell^{r} can always cause totally different candidate blocks to be received by the honest verifiers of the second step.1212 12 For instance, to keep it simple (but extreme), “when the time of the second step is about to expire”, ℓr\\ell^{r} could directly email a different candidate block BiB\_{i} to each user ii. This way, whoever the step-2 verifiers might be, they will have received totally different blocks. Once this is the case, it is easy to ensure that the block ultimately agreed upon via the BA protocol of round rr will be the default one, and thus will not contain anyone’s digital signature of Qr−1Q^{r-1}. But the system must continue, and for this, it needs a leader for round rr. If this leader is automatically and openly selected, then the Adversary will trivially corrupt him. If it is selected by the previous Qr−1Q^{r-1} via the same process, than ℓr\\ell^{r} will again be the leader in round r+1r+1. We specifically propose to use the same secret cryptographic sortition mechanism, but applied to a new QQ\-quantity: namely, H⁡(Qr−1,r)H(Q^{r-1},r). By having this quantity to be the output of HH guarantees that the output is random, and by including rr as the second input of HH, while all other uses of HH have one or 3+3+ inputs, “guarantees” that such a QrQ^{r} is independently selected. Again, our specific choice of alternative QrQ^{r} does not matter, what matter is that ℓr\\ell^{r} has two choice for QrQ^{r}, and thus he can double his chances to have another malicious user as the next leader.

The options for QrQ^{r} may even be more numerous for the Adversary who controls a malicious ℓr\\ell^{r}. For instance, let xx, yy, and zz be three malicious potential leaders of round rr such that

H⁡(σxr,1)<H⁡(σyr,1)<H⁡(σzr,1)H\\left(\\sigma\_{x}^{r,1}\\right)<H\\left(\\sigma\_{y}^{r,1}\\right)<H\\left(\\sigma\_{z}^{r,1}\\right)

and H⁡(σzr,1)H\\left(\\sigma\_{z}^{r,1}\\right) is particulary small. That is, so small that there is a good chance that H⁡(σzr,1)H\\left(\\sigma\_{z}^{r,1}\\right) is smaller of the hashed credential of every honest potential leader. Then, by asking xx to hide his credential, the Adversary has a good chance of having yy become the leader of round r−1r-1. This implies that he has another option for QrQ^{r}: namely, S​I​Gy​(Qr−1)SIG\_{y}\\left(Q^{r-1}\\right). Similarly, the Adversary may ask both xx and yy of withholding their credentials, so as to have zz become the leader of round r−1r-1 and gaining another option for QrQ^{r}: namely, S​I​Gz​(Qr−1)SIG\_{z}\\left(Q^{r-1}\\right).

Of course, however, each of these and other options has a non-zero chance to fail, because the Adversary cannot predict the hash of the digital signatures of the honest potential users.

A careful, Markov-chain-like analysis shows that, no matter what options the Adversary chooses to make at round r−1r-1, as long as he cannot inject new users in the system, he cannot decrease the probability of an honest user to be the leader of round r+40r+40 much below hh. This is the reason for which we demand that the potential leaders of round rr are users already existing in round r−kr-k. It is a way to ensure that, at round r−kr-k, the Adversary cannot alter by much the probability that an honest user become the leader of round rr. In fact, no matter what users he may add to the system in rounds r−kr-k through rr, they are ineligible to become potential leaders (and a fortiori the leader) of round rr. Thus the look-back parameter kk ultimately is a security parameter. (Although, as we shall see in section [7](#S7 "7 Handling Offline Honest users ‣ ALGORAND"), it can also be a kind of “convenience parameter” as well.)

##### Ephemeral Keys

Although the execution of our protocol cannot generate a fork, except with negligible probability, the Adversary could generate a fork, at the rrth block, after the legitimate block rr has been generated.

Roughly, once BrB^{r} has been generated, the Adversary has learned who the verifiers of each step of round rr are. Thus, he could therefore corrupt all of them and oblige them to certify a new block Br~\\widetilde{B^{r}}. Since this fake block might be propagated only after the legitimate one, users that have been paying attention would not be fooled.1313 13 Consider corrupting the news anchor of a major TV network, and producing and broadcasting today a newsreel showing secretary Clinton winning the last presidential election. Most of us would recognize it as a hoax. But someone getting out of a coma might be fooled. Nonetheless, Br~\\widetilde{B^{r}} would be syntactically correct and we want to prevent from being manufactured.

We do so by means of a new rule. Essentially, the members of the verifier set S​Vr,sSV^{r,s} of a step ss of round rr use ephemeral public keys p​kir,spk\_{i}^{r,s} to digitally sign their messages. These keys are single-use-only and their corresponding secret keys s​kir,ssk^{r,s}\_{i} are destroyed once used. This way, if a verifier is corrupted later on, the Adversary cannot force him to sign anything else he did not originally sign.

Naturally, we must ensure that it is impossible for the Adversary to compute a new key pir,s~\\widetilde{p\_{i}^{r,s}} and convince an honest user that it is the right ephemeral key of verifier i∈S​Vr,si\\in SV^{r,s} to use in step ss.

### 4.2 Common Summary of Notations, Notions, and Parameters

##### Notations

-   ∙\\bullet
    
    r≥0r\\geq 0: the current round number.
    
-   ∙\\bullet
    
    s≥1s\\geq 1: the current step number in round rr.
    
-   ∙\\bullet
    
    BrB^{r}: the block generated in round rr.
    
-   ∙\\bullet
    
    P​KrPK^{r}: the set of public keys by the end of round r−1r-1 and at the beginning of round rr.
    
-   ∙\\bullet
    
    SrS^{r}: the system status by the end of round r−1r-1 and at the beginning of round rr.1414 14 In a system that is not synchronous, the notion of “the end of round r−1r-1” and “the beginning of round rr” need to be carefully defined. Mathematically, P​KrPK^{r} and SrS^{r} are computed from the initial status S0S^{0} and the blocks B1,…,Br−1B^{1},\\dots,B^{r-1}.
    
-   ∙\\bullet
    
    P​A​YrPAY^{r}: the payset contained in BrB^{r}.
    
-   ∙\\bullet
    
    ℓr\\ell^{r}: round-rr leader. ℓr\\ell^{r} chooses the payset P​A​YrPAY^{r} of round rr (and determines the next QrQ^{r}).
    
-   ∙\\bullet
    
    QrQ^{r}: the seed of round rr, a quantity (i.e., binary string) that is generated at the end of round rr and is used to choose verifiers for round r+1r+1. QrQ^{r} is independent of the paysets in the blocks and cannot be manipulated by ℓr\\ell^{r}.
    
-   ∙\\bullet
    
    S​Vr,sSV^{r,s}: the set of verifiers chosen for step ss of round rr.
    
-   ∙\\bullet
    
    S​VrSV^{r}: the set of verifiers chosen for round rr, SVr\=∪s≥1SVr,sSV^{r}=\\cup\_{s\\geq 1}SV^{r,s}.
    
-   ∙\\bullet
    
    M​S​Vr,sMSV^{r,s} and H​S​Vr,sHSV^{r,s}: respectively, the set of malicious verifiers and the set of honest verifiers in S​Vr,sSV^{r,s}. M​S​Vr,s∪H​S​Vr,s\=S​Vr,sMSV^{r,s}\\cup HSV^{r,s}=SV^{r,s} and M​S​Vr,s∩H​S​Vr,s\=∅MSV^{r,s}\\cap HSV^{r,s}=\\emptyset.
    
-   ∙\\bullet
    
    n1∈ℤ+n\_{1}\\in\\mathbb{Z}^{+} and n∈ℤ+n\\in\\mathbb{Z}^{+}: respectively, the expected numbers of potential leaders in each S​Vr,1SV^{r,1}, and the expected numbers of verifiers in each S​Vr,sSV^{r,s}, for s\>1s>1.
    
    Notice that n1<<nn\_{1}<<n, since we need at least one honest honest member in S​Vr,1SV^{r,1}, but at least a majority of honest members in each S​Vr,sSV^{r,s} for s\>1s>1.
    
-   ∙\\bullet
    
    h∈(0,1)h\\in(0,1): a constant greater than 2/3. hh is the honesty ratio in the system. That is, the fraction of honest users or honest money, depending on the assumption used, in each P​KrPK^{r} is at least hh.
    
-   ∙\\bullet
    
    HH: a cryptographic hash function, modelled as a random oracle.
    
-   ∙\\bullet
    
    ⊥\\bot: A special string of the same length as the output of HH.
    
-   ∙\\bullet
    
    F∈(0,1)F\\in(0,1): the parameter specifying the allowed error probability. A probability ≤F\\leq F is considered “negligible”, and a probability ≥1−F\\geq 1-F is considered “overwhelming”.
    
-   ∙\\bullet
    
    ph∈(0,1)p\_{h}\\in(0,1): the probability that the leader of a round rr, ℓr\\ell^{r}, is honest. Ideally ph\=hp\_{h}=h. With the existence of the Adversary, the value of php\_{h} will be determined in the analysis.
    
-   ∙\\bullet
    
    k∈ℤ+k\\in\\mathbb{Z}^{+}: the look-back parameter. That is, round r−kr-k is where the verifiers for round rr are chosen from —namely, S​Vr⊆P​Kr−kSV^{r}\\subseteq PK^{r-k}.1515 15 Strictly speaking, “r−kr-k” should be “max⁡{0,r−k}\\max\\{0,r-k\\}”.
    
-   ∙\\bullet
    
    p1∈(0,1)p\_{1}\\in(0,1): for the first step of round rr, a user in round r−kr-k is chosen to be in S​Vr,1SV^{r,1} with probability p1≜n1|P​Kr−k|p\_{1}\\triangleq\\frac{n\_{1}}{|PK^{r-k}|}.
    
-   ∙\\bullet
    
    p∈(0,1)p\\in(0,1): for each step s\>1s>1 of round rr, a user in round r−kr-k is chosen to be in S​Vr,sSV^{r,s} with probability p≜n|P​Kr−k|p\\triangleq\\frac{n}{|PK^{r-k}|}.
    
-   ∙\\bullet
    
    C​E​R​TrCERT^{r}: the certificate for BrB^{r}. It is a set of tHt\_{H} signatures of H⁡(Br)H(B^{r}) from proper verifiers in round rr.
    
-   ∙\\bullet
    
    Br¯≜(Br,C​E​R​Tr)\\overline{B^{r}}\\triangleq(B^{r},CERT^{r}) is a proven block.
    
    A user ii knows BrB^{r} if he possesses (and successfully verifies) both parts of the proven block. Note that the C​E​R​TrCERT^{r} seen by different users may be different.
    
-   ∙\\bullet
    
    τir\\tau\_{i}^{r}: the (local) time at which a user ii knows BrB^{r}. In the Algorand protocol each user has his own clock. Different users’ clocks need not be synchronized, but must have the same speed. Only for the purpose of the analysis, we consider a reference clock and measure the players’ related times with respect to it.
    
-   ∙\\bullet
    
    αir,s\\alpha^{r,s}\_{i} and βir,s\\beta^{r,s}\_{i}: respectively the (local) time a user ii starts and ends his execution of Step ss of round rr.
    
-   ∙\\bullet
    
    Λ\\Lambda and λ\\lambda: essentially, the upper-bounds to, respectively, the time needed to execute Step 1 and the time needed for any other step of the Algorand protocol.
    
    Parameter Λ\\Lambda upper-bounds the time to propagate a single 1MB block. (In our notation, Λ\=λρ,1​M​B\\Lambda=\\lambda\_{\\rho,1MB}. Recalling our notation, that we set ρ\=1\\rho=1 for simplicity, and that blocks are chosen to be at most 1MB-long, we have Λ\=λ1,1,1​M​B\\Lambda=\\lambda\_{1,1,1MB}.)
    
    Parameter λ\\lambda upperbounds the time to propagate one small message per verifier in a Step s\>1s>1. (Using, as in Bitcoin, elliptic curve signatures with 32B keys, a verifier message is 200B long. Thus, in our notation, λ\=λn,ρ,200​B\\lambda=\\lambda\_{n,\\rho,200B}.)
    
    We assume that Λ\=O⁡(λ)\\Lambda=O(\\lambda).
    

##### Notions

-   •
    
    Verifier selection.
    
    For each round rr and step s\>1s>1, SVr,s≜{i∈PKr−k:.H(SIGi(r,s,Qr−1))≤p}SV^{r,s}\\triangleq\\{i\\in PK^{r-k}:\\ .H(SIG\_{i}(r,s,Q^{r-1}))\\leq p\\}. Each user i∈P​Kr−ki\\in PK^{r-k} privately computes his signature using his long-term key and decides whether i∈S​Vr,si\\in SV^{r,s} or not. If i∈S​Vr,si\\in SV^{r,s}, then S​I​Gi​(r,s,Qr−1)SIG\_{i}(r,s,Q^{r-1}) is ii’s (r,s)(r,s)\-credential, compactly denoted by σir,s\\sigma\_{i}^{r,s}.
    
    For the first step of round rr, S​Vr,1SV^{r,1} and σir,1\\sigma\_{i}^{r,1} are similarly defined, with pp replaced by p1p\_{1}. The verifiers in S​Vr,1SV^{r,1} are potential leaders.
    
-   •
    
    Leader selection.
    
    User i∈S​Vr,1i\\in SV^{r,1} is the leader of round rr, denoted by ℓr\\ell^{r}, if H⁡(σir,1)≤H⁡(σjr,1)H(\\sigma\_{i}^{r,1})\\leq H(\\sigma\_{j}^{r,1}) for all potential leaders j∈S​Vr,1j\\in SV^{r,1}. Whenever the hashes of two players’ credentials are compared, in the unlikely event of ties, the protocol always breaks ties lexicographically according to the (long-term public keys of the) potential leaders.
    
    By definition, the hash value of player ℓr\\ell^{r}’s credential is also the smallest among all users in P​Kr−kPK^{r-k}. Note that a potential leader cannot privately decide whether he is the leader or not, without seeing the other potential leaders’ credentials.
    
    Since the hash values are uniform at random, when S​Vr,1SV^{r,1} is non-empty, ℓr\\ell^{r} always exists and is honest with probability at least hh. The parameter n1n\_{1} is large enough so as to ensure that each S​Vr,1SV^{r,1} is non-empty with overwhelming probability.
    
-   •
    
    Block structure.
    
    A non-empty block is of the form Br\=(r,P​A​Yr,S​I​Gℓr​(Qr−1),H⁡(Br−1))B^{r}=(r,PAY^{r},SIG\_{\\ell^{r}}(Q^{r-1}),H(B^{r-1})), and an empty block is of the form Bϵr\=(r,∅,Qr−1,H⁡(Br−1))B^{r}\_{\\epsilon}=(r,\\emptyset,Q^{r-1},H(B^{r-1})).
    
    Note that a non-empty block may still contain an empty payset P​A​YrPAY^{r}, if no payment occurs in this round or if the leader is malicious. However, a non-empty block implies that the identity of ℓr\\ell^{r}, his credential σℓrr,1\\sigma^{r,1}\_{\\ell^{r}} and S​I​Gℓr​(Qr−1)SIG\_{\\ell^{r}}(Q^{r-1}) have all been timely revealed. The protocol guarantees that, if the leader is honest, then the block will be non-empty with overwhelming probability.
    
-   •
    
    Seed QrQ^{r}.
    
    If BrB^{r} is non-empty, then Qr≜H⁡(S​I​Gℓr​(Qr−1),r)Q^{r}\\triangleq H(SIG\_{\\ell^{r}}(Q^{r-1}),r), otherwise Qr≜H⁡(Qr−1,r)Q^{r}\\triangleq H(Q^{r-1},r).
    

##### Parameters

-   ∙\\bullet
    
    Relationships among various parameters.
    
    -   —
        
        The verifiers and potential leaders of round rr are selected from the users in P​Kr−kPK^{r-k}, where kk is chosen so that the Adversary cannot predict Qr−1Q^{r-1} back at round r−k−1r-k-1 with probability better than FF: otherwise, he will be able to introduce malicious users for round r−kr-k, all of which will be potential leaders/verifiers in round rr, succeeding in having a malicious leader or a malicious majority in S​Vr,sSV^{r,s} for some steps ss desired by him.
        
    -   —
        
        For Step 1 of each round rr, n1n\_{1} is chosen so that with overwhelming probability, S​Vr,1≠∅SV^{r,1}\\neq\\emptyset.
        
    
-   ∙\\bullet
    
    Example choices of important parameters.
    
    -   —
        
        The outputs of HH are 256-bit long.
        
    -   —
        
        h\=80%h=80\\%, n1\=35n\_{1}=35.
        
    -   —
        
        Λ\=\\Lambda= 1 minute and λ\=\\lambda= 10 seconds.
        
    
-   ∙\\bullet
    
    Initialization of the protocol.
    
    The protocol starts at time 00 with r\=0r=0. Since there does not exist “B−1B^{-1}” or “C​E​R​T−1CERT^{-1}”, syntactically B−1B^{-1} is a public parameter with its third component specifying Q−1Q^{-1}, and all users know B−1B^{-1} at time 0.
    

## 5 Algorand𝟏′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{1}}

In this section, we construct a version of Algorand′\\text{{Algorand}}\\,^{\\prime} working under the following assumption.

Honest Majority of Users Assumption:

More than 2/3 of the users in each P​KrPK^{r} are honest.

In Section [8](#S8 "8 Protocol \"Algorand\"^′ with Honest Majority of Money ‣ ALGORAND"), we show how to replace the above assumption with the desired Honest Majority of Money assumption.

### 5.1 Additional Notations and Parameters

##### Notations

-   ∙\\bullet
    
    m∈ℤ+m\\in\\mathbb{Z}^{+}: the maximum number of steps in the binary BA protocol, a multiple of 3.
    
-   ∙\\bullet
    
    Lr≤m/3L^{r}\\leq m/3: a random variable representing the number of Bernoulli trials needed to see a 1, when each trial is 1 with probability ph2\\frac{p\_{h}}{2} and there are at most m/3m/3 trials. If all trials fail then Lr≜m/3L^{r}\\triangleq m/3. LrL^{r} will be used to upper-bound the time needed to generate block BrB^{r}.
    
-   ∙\\bullet
    
    tH\=2​n3+1t\_{H}=\\frac{2n}{3}+1: the number of signatures needed in the ending conditions of the protocol.
    
-   ∙\\bullet
    
    C​E​R​TrCERT^{r}: the certificate for BrB^{r}. It is a set of tHt\_{H} signatures of H⁡(Br)H(B^{r}) from proper verifiers in round rr.
    

##### Parameters

-   ∙\\bullet
    
    Relationships among various parameters.
    
    -   —
        
        For each step s\>1s>1 of round rr, nn is chosen so that, with overwhelming probability,
        
        |H​S​Vr,s|\>2​|M​S​Vr,s||HSV^{r,s}|>2|MSV^{r,s}|  and  |H​S​Vr,s|+4​|M​S​Vr,s|<2​n|HSV^{r,s}|+4|MSV^{r,s}|<2n.
        
        The closer to 1 the value of hh is, the smaller nn needs to be. In particular, we use (variants of) Chernoff bounds to ensure the desired conditions hold with overwhelming probability.
        
    -   —
        
        mm is chosen such that Lr<m/3L^{r}<m/3 with overwhelming probability.
        
    
-   ∙\\bullet
    
    Example choices of important parameters.
    
    -   —
        
        F\=10−12F=10^{-12}.
        
    -   —
        
        n≈1500n\\approx 1500, k\=40k=40 and m\=180m=180.
        
    

### 5.2 Implementing Ephemeral Keys in Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1}

As already mentioned, we wish that a verifier i∈S​Vr,si\\in SV^{r,s} digitally signs his message mir,sm\_{i}^{r,s} of step ss in round rr, relative to an ephemeral public key p​kir,spk\_{i}^{r,s}, using an ephemeral secrete key s​kir,ssk^{r,s}\_{i} that he promptly destroys after using. We thus need an efficient method to ensure that every user can verify that p​kir,spk\_{i}^{r,s} is indeed the key to use to verify ii’s signature of mir,sm\_{i}^{r,s}. We do so by a (to the best of our knowledge) new use of identity-based signature schemes.

At a high level, in such a scheme, a central authority AA generates a public master key, P​M​KPMK, and a corresponding secret master key, S​M​KSMK. Given the identity, UU, of a player UU, AA computes, via S​M​KSMK, a secret signature key s​kUsk\_{U} relative to the public key UU, and privately gives s​kUsk\_{U} to UU. (Indeed, in an identity-based digital signature scheme, the public key of a user UU is UU itself!) This way, if AA destroys S​M​KSMK after computing the secret keys of the users he wants to enable to produce digital signatures, and does not keep any computed secret key, then UU is the only one who can digitally sign messages relative to the public key UU. Thus, anyone who knows “UU’s name”, automatically knows UU’s public key, and thus can verify UU’s signatures (possibly using also the public master key P​M​KPMK).

In our application, the authority AA is user ii, and the set of all possible users UU coincides with the round-step pair (r,s)(r,s) in —say— S\={i}×{r′,…,r′+106}×{1,…,m+3}S=\\{i\\}\\times\\{r^{\\prime},\\ldots,r^{\\prime}+10^{6}\\}\\times\\{1,\\ldots,m+3\\}, where r′r^{\\prime} is a given round, and m+3m+3 the upperbound to the number of steps that may occur within a round. This way, p​kir,s≜(i,r,s)pk\_{i}^{r,s}\\triangleq(i,r,s), so that everyone seeing ii’s signature S​I​Gp​kir,sr,s​(mir,s)SIG\_{pk^{r,s}\_{i}}^{r,s}(m\_{i}^{r,s}) can, with overwhelming probability, immediately verify it for the first million rounds rr following r′r^{\\prime}.

In other words, ii first generates P​M​KPMK and S​M​KSMK. Then, he publicizes that P​M​KPMK is ii’s master public key for any round r∈\[r′,r′+106\]r\\in\[r^{\\prime},r^{\\prime}+10^{6}\], and uses S​M​KSMK to privately produce and store the secret key s​kir,ssk^{r,s}\_{i} for each triple (i,r,s)∈S(i,r,s)\\in S. This done, he destroys S​M​KSMK. If he determines that he is not part of S​Vr,sSV^{r,s}, then ii may leave s​kir,ssk^{r,s}\_{i} alone (as the protocol does not require that he aunthenticates any message in Step ss of round rr). Else, ii first uses s​kir,ssk^{r,s}\_{i} to digitally sign his message mir,sm\_{i}^{r,s}, and then destroys s​kir,ssk^{r,s}\_{i}.

Note that ii can publicize his first public master key when he first enters the system. That is, the same payment ℘\\wp that brings ii into the system (at a round r′r^{\\prime} or at a round close to r′r^{\\prime}), may also specify, at ii’s request, that ii’s public master key for any round r∈\[r′,r′+106\]r\\in\[r^{\\prime},r^{\\prime}+10^{6}\] is P​M​KPMK —e.g., by including a pair of the form (P​M​K,\[r′,r′+106\])(PMK,\[r^{\\prime},r^{\\prime}+10^{6}\]).

Also note that, since m+3m+3 is the maximum number of steps in a round, assuming that a round takes a minute, the stash of ephemeral keys so produced will last ii for almost two years. At the same time, these ephemeral secret keys will not take ii too long to produce. Using an elliptic-curve based system with 32B keys, each secret key is computed in a few microseconds. Thus, if m+3\=180m+3=180, then all 180M secret keys can be computed in less than one hour.

When the current round is getting close to r′+106r^{\\prime}+10^{6}, to handle the next million rounds, ii generates a new (P​M​K′,S​M​K′)(PMK^{\\prime},SMK^{\\prime}) pair, and informs what his next stash of ephemeral keys is by —for example— having S​I​Gi​(P​M​K′,\[r′+106+1,r′+2⋅106+1\])SIG\_{i}(PMK^{\\prime},\[r^{\\prime}+10^{6}+1,r^{\\prime}+2\\cdot 10^{6}+1\]) enter a new block, either as a separate “transaction” or as some additional information that is part of a payment. By so doing, ii informs everyone that he/she should use P​M​K′PMK^{\\prime} to verify ii’s ephemeral signatures in the next million rounds. And so on.

(Note that, following this basic approach, other ways for implementing ephemeral keys without using identity-based signatures are certainly possible. For instance, via Merkle trees.1616 16 In this method, ii generates a public-secret key pair (p​kir,s,s​kir,s)(pk\_{i}^{r,s},sk\_{i}^{r,s}) for each round-step pair (r,s)(r,s) in —say— {r′,…,r′+106}×{1,…,m+3}\\{r^{\\prime},\\ldots,r^{\\prime}+10^{6}\\}\\times\\{1,\\ldots,m+3\\}. Then he orders these public keys in a canonical way, stores the jjth public key in the jjth leaf of a Merkle tree, and computes the root value RiR\_{i}, which he publicizes. When he wants to sign a message relative to key p​kir,spk\_{i}^{r,s}, ii not only provides the actual signature, but also the authenticating path for p​kir,spk\_{i}^{r,s} relative to RiR\_{i}. Notice that this authenticating path also proves that p​kir,spk\_{i}^{r,s} is stored in the jjth leaf. The rest of the details can be easily filled.)

Other ways for implementing ephemeral keys are certainly possible —e.g., via Merkle trees.

### 5.3 Matching the Steps of Algorand𝟏′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{1}} with those of 𝑩​𝑨⋆\\bm{BA^{\\star}}

As we said, a round in Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1} has at most m+3m+3 steps.

Step 1.

In this step, each potential leader ii computes and propagates his candidate block BirB^{r}\_{i}, together with his own credential, σir,1\\sigma\_{i}^{r,1}.

Recall that this credential explicitly identifies ii. This is so, because σir,1≜S​I​Gi​(r,1,Qr−1)\\sigma\_{i}^{r,1}\\triangleq SIG\_{i}(r,1,Q^{r-1}).

Potential verifier ii also propagates, as part of his message, his proper digital signature of H⁡(Bir)H(B^{r}\_{i}). Not dealing with a payment or a credential, this signature of ii is relative to his ephemeral public key p​kir,1pk\_{i}^{r,1}: that is, he propagates s​i​gp​kir,1​(H⁡(Bir))sig\_{pk\_{i}^{r,1}}(H(B^{r}\_{i})).

Given our conventions, rather than propagating BirB^{r}\_{i} and s​i​gp​kir,1​(H⁡(Bir))sig\_{pk\_{i}^{r,1}}(H(B^{r}\_{i})), he could have propagated S​I​Gp​kir,1​(H⁡(Bir))SIG\_{pk\_{i}^{r,1}}(H(B^{r}\_{i})). However, in our analysis we need to have explicit access to s​i​gp​kir,1​(H⁡(Bir))sig\_{pk\_{i}^{r,1}}(H(B^{r}\_{i})).

Steps 2.

In this step, each verifier ii sets ℓir\\ell\_{i}^{r} to be the potential leader whose hashed credential is the smallest, and BirB^{r}\_{i} to be the block proposed by ℓir\\ell^{r}\_{i}. Since, for the sake of efficiency, we wish to agree on H⁡(Br)H(B^{r}), rather than directly on BrB^{r}, ii propagates the message he would have propagated in the first step of B​A⋆BA^{\\star} with initial value vi′\=H⁡(Bir)v\_{i}^{\\prime}=H(B\_{i}^{r}). That is, he propagates vi′v\_{i}^{\\prime}, after ephemerally signing it, of course. (Namely, after signing it relative to the right ephemeral public key, which in this case is p​kir,2pk\_{i}^{r,2}.) Of course too, ii also transmits his own credential.

Since the first step of B​A⋆BA^{\\star} consists of the first step of the graded consensus protocol G​CGC, Step 2 of Algorand′\\text{{Algorand}}\\,^{\\prime} corresponds to the first step of G​CGC.

Steps 3.

In this step, each verifier i∈S​Vr,2i\\in SV^{r,2} executes the second step of B​A⋆BA^{\\star}. That is, he sends the same message he would have sent in the second step of G​CGC. Again, ii’s message is ephemerally signed and accompanied by ii’s credential. (From now on, we shall omit saying that a verifier ephemerally signs his message and also propagates his credential.)

Step 4.

In this step, every verifier i∈S​Vr,4i\\in SV^{r,4} computes the output of G​CGC, (vi,gi)(v\_{i},g\_{i}), and ephemerally signs and sends the same message he would have sent in the third step of B​A⋆BA^{\\star}, that is, in the first step of B​B​A⋆BBA^{\\star}, with initial bit 0 if gi\=2g\_{i}=2, and 1 otherwise.

Step s\=5,…,m+2s=5,\\ldots,m+2.

Such a step, if ever reached, corresponds to step s−1s-1 of B​A⋆BA^{\\star}, and thus to step s−3s-3 of B​B​A⋆BBA^{\\star}.

Since our propagation model is sufficiently asynchronous, we must account for the possibility that, in the middle of such a step ss, a verifier i∈S​Vr,si\\in SV^{r,s} is reached by information proving him that block BrB^{r} has already been chosen. In this case, ii stops his own execution of round rr of Algorand′\\text{{Algorand}}\\,^{\\prime}, and starts executing his round-(r+1)(r+1) instructions.

Accordingly, the instructions of a verifier i∈S​Vr,si\\in SV^{r,s}, in addition to the instructions corresponding to Step s−3s-3 of B​B​A⋆BBA^{\\star}, include checking whether the execution of B​B​A⋆BBA^{\\star} has halted in a prior Step s′s^{\\prime}. Since B​B​A⋆BBA^{\\star} can only halt is a Coin-Fixed-to-0 Step or in a Coin-Fixed-to-1 step, the instructions distinguish whether

A (Ending Condition 0): s′−2≡0​m​o​d​ 3s^{\\prime}-2\\equiv 0\\;mod\\;3, or

B (Ending Condition 1): s′−2≡1​m​o​d​ 3s^{\\prime}-2\\equiv 1\\;mod\\;3.

In fact, in case A, the block BrB^{r} is non-empty, and thus additional instructions are necessary to ensure that ii properly reconstructs BrB^{r}, together with its proper certificate C​E​R​TrCERT^{r}. In case B, the block BrB^{r} is empty, and thus ii is instructed to set Br\=Bεr\=(r,∅,H⁡(Qr−1,r),H⁡(Br−1))B^{r}=B^{r}\_{\\varepsilon}=(r,\\emptyset,H(Q^{r-1},r),H(B^{r-1})), and to compute C​E​R​TrCERT^{r}.

If, during his execution of step ss, ii does not see any evidence that the block BrB^{r} has already been generated, then he sends the same message he would have sent in step s−3s-3 of B​B​A⋆BBA^{\\star}.

Step m+3m+3.

If, during step m+3m+3, i∈S​Vr,m+3i\\in SV^{r,m+3} sees that the block BrB^{r} was already generated in a prior step s′s^{\\prime}, then he proceeds just as explained above.

Else, rather then sending the same message he would have sent in step mm of B​B​A⋆BBA^{\\star}, ii is instructed, based on the information in his possession, to compute BrB^{r} and its corresponding certificate C​E​R​TrCERT^{r}.

Recall, in fact, that we upperbound by m+3m+3 the total number of steps of a round.

### 5.4 The Actual Protocol

Recall that, in each step ss of a round rr, a verifier i∈S​Vr,si\\in SV^{r,s} uses his long-term public-secret key pair to produce his credential, σir,s≜S​I​Gi​(r,s,Qr−1)\\sigma\_{i}^{r,s}\\triangleq SIG\_{i}(r,s,Q^{r-1}), as well as S​I​Gi​(Qr−1)SIG\_{i}\\left(Q^{r-1}\\right) in case s\=1s=1. Verifier ii uses his ephemeral secret key s​kir,ssk\_{i}^{r,s} to sign his (r,s)(r,s)\-message mir,sm\_{i}^{r,s}. For simplicity, when rr and ss are clear, we write e​s​i​gi​(x)esig\_{i}(x) rather than s​i​gp​kir,s​(x)sig\_{pk^{r,s}\_{i}}(x) to denote ii’s proper ephemeral signature of a value xx in step ss of round rr, and write E​S​I​Gi​(x)ESIG\_{i}(x) instead of S​I​Gp​kir,s​(x)SIG\_{pk\_{i}^{r,s}}(x) to denote (i,x,e​s​i​gi​(x))(i,x,esig\_{i}(x)).

Step 1: Block Proposal Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step 1 of round rr as soon as he knows Br−1B^{r-1}. • User ii computes Qr−1Q^{r-1} from the third component of Br−1B^{r-1} and checks whether i∈S​Vr,1i\\in SV^{r,1} or not. • If i∉S​Vr,1i\\notin SV^{r,1}, then ii stops his own execution of Step 1 right away. • If i∈S​Vr,1i\\in SV^{r,1}, that is, if ii is a potential leader, then he collects the round-rr payments that have been propagated to him so far and computes a maximal payset P​A​YirPAY^{r}\_{i} from them. Next, he computes his “candidate block” Bir\=(r,P​A​Yir,S​I​Gi​(Qr−1),H⁡(Br−1))B^{r}\_{i}=(r,PAY^{r}\_{i},SIG\_{i}(Q^{r-1}),H(B^{r-1})). Finally, he computes the message mir,1\=(Bir,e​s​i​gi​(H⁡(Bir)),σir,1)m^{r,1}\_{i}=(B^{r}\_{i},esig\_{i}(H(B^{r}\_{i})),\\sigma^{r,1}\_{i}), destroys his ephemeral secret key s​kir,1sk^{r,1}\_{i}, and then propagates mir,1m^{r,1}\_{i}.

##### Remark.

In practice, to shorten the global execution of Step 1, it is important that the (r,1)(r,1)\-messages are selectively propagated. That is, for every user ii in the system, for the first (r,1)(r,1)\-message that he ever receives and successfully verifies,1717 17 That is, all the signatures are correct and both the block and its hash are valid —although ii does not check whether the included payset is maximal for its proposer or not. player ii propagates it as usual. For all the other (r,1)(r,1)\-messages that player ii receives and successfully verifies, he propagates it only if the hash value of the credential it contains is the smallest among the hash values of the credentials contained in all (r,1)(r,1)\-messages he has received and successfully verified so far. Furthermore, as suggested by Georgios Vlachos, it is useful that each potential leader ii also propagates his credential σir,1\\sigma^{r,1}\_{i} separately: those small messages travel faster than blocks, ensure timely propagation of the mjr,1m^{r,1}\_{j}’s where the contained credentials have small hash values, while make those with large hash values disappear quickly.

Step 2: The First Step of the Graded Consensus Protocol G​CGC Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step 2 of round rr as soon as he knows Br−1B^{r-1}. • User ii computes Qr−1Q^{r-1} from the third component of Br−1B^{r-1} and checks whether i∈S​Vr,2i\\in SV^{r,2} or not. • If i∉S​Vr,2i\\notin SV^{r,2} then ii stops his own execution of Step 2 right away. • If i∈S​Vr,2i\\in SV^{r,2}, then after waiting an amount of time t2≜λ+Λt\_{2}\\triangleq\\lambda+\\Lambda, ii acts as follows. 1. He finds the user ℓ\\ell such that H⁡(σℓr,1)≤H⁡(σjr,1)H(\\sigma^{r,1}\_{\\ell})\\leq H(\\sigma^{r,1}\_{j}) for all credentials σjr,1\\sigma^{r,1}\_{j} that are part of the successfully verified (r,1)(r,1)\-messages he has received so far.1818 18 Essentially, user ii privately decides that the leader of round rr is user ℓ\\ell. 2. If he has received from ℓ\\ell a valid message mℓr,1\=(Bℓr,e​s​i​gℓ​(H⁡(Bℓr)),σℓr,1)m^{r,1}\_{\\ell}=(B^{r}\_{\\ell},esig\_{\\ell}(H(B^{r}\_{\\ell})),\\sigma^{r,1}\_{\\ell}),1919 19 Again, player ℓ\\ell’s signatures and the hashes are all successfully verified, and P​A​YℓrPAY^{r}\_{\\ell} in BℓrB^{r}\_{\\ell} is a valid payset for round rr —although ii does not check whether P​A​YℓrPAY^{r}\_{\\ell} is maximal for ℓ\\ell or not. then ii sets vi′≜H⁡(Bℓr)v^{\\prime}\_{i}\\triangleq H(B^{r}\_{\\ell}); otherwise ii sets v′i≜⊥v^{\\prime}\_{i}\\triangleq\\bot. 3. ii computes the message mir,2≜(E​S​I​Gi​(vi′),σir,2)m^{r,2}\_{i}\\triangleq(ESIG\_{i}(v^{\\prime}\_{i}),\\sigma^{r,2}\_{i}),2020 20 The message mir,2m^{r,2}\_{i} signals that player ii considers vi′v^{\\prime}\_{i} to be the hash of the next block, or considers the next block to be empty. destroys his ephemeral secret key s​kir,2sk^{r,2}\_{i}, and then propagates mir,2m^{r,2}\_{i}.

Step 3: The Second Step of G​CGC Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step 3 of round rr as soon as he knows Br−1B^{r-1}. • User ii computes Qr−1Q^{r-1} from the third component of Br−1B^{r-1} and checks whether i∈S​Vr,3i\\in SV^{r,3} or not. • If i∉S​Vr,3i\\notin SV^{r,3}, then ii stops his own execution of Step 3 right away. • If i∈S​Vr,3i\\in SV^{r,3}, then after waiting an amount of time t3≜t2+2​λ\=3​λ+Λt\_{3}\\triangleq t\_{2}+2\\lambda=3\\lambda+\\Lambda, ii acts as follows. 1. If there exists a value v′≠⊥v^{\\prime}\\neq\\bot such that, among all the valid messages mjr,2m\_{j}^{r,2} he has received, more than 2/3 of them are of the form (E​S​I​Gj​(v′),σjr,2)(ESIG\_{j}(v^{\\prime}),\\sigma\_{j}^{r,2}), without any contradiction,2121 21 That is, he has not received two valid messages containing E​S​I​Gj​(v′)ESIG\_{j}(v^{\\prime}) and a different E​S​I​Gj​(v′′)ESIG\_{j}(v^{\\prime\\prime}) respectively, from a player jj. Here and from here on, except in the Ending Conditions defined later, whenever an honest player wants messages of a given form, messages contradicting each other are never counted or considered valid. then he computes the message mir,3≜(E​S​I​Gi​(v′),σir,3)m\_{i}^{r,3}\\triangleq(ESIG\_{i}(v^{\\prime}),\\sigma^{r,3}\_{i}). Otherwise, he computes mir,3≜(E​S​I​Gi​(⊥),σir,3)m\_{i}^{r,3}\\triangleq(ESIG\_{i}(\\bot),\\sigma^{r,3}\_{i}). 2. ii destroys his ephemeral secret key s​kir,3sk^{r,3}\_{i}, and then propagates mir,3m\_{i}^{r,3}.

Step 4: Output of G​CGC and The First Step of B​B​A⋆BBA^{\\star} Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step 4 of round rr as soon as he knows Br−1B^{r-1}. • User ii computes Qr−1Q^{r-1} from the third component of Br−1B^{r-1} and checks whether i∈S​Vr,4i\\in SV^{r,4} or not. • If i∉S​Vr,4i\\notin SV^{r,4}, then ii his stops his own execution of Step 4 right away. • If i∈S​Vr,4i\\in SV^{r,4}, then after waiting an amount of time t4≜t3+2​λ\=5​λ+Λt\_{4}\\triangleq t\_{3}+2\\lambda=5\\lambda+\\Lambda, ii acts as follows. 1. He computes viv\_{i} and gig\_{i}, the output of GC, as follows. (a) If there exists a value v′≠⊥v^{\\prime}\\neq\\bot such that, among all the valid messages mjr,3m\_{j}^{r,3} he has received, more than 2/3 of them are of the form (E​S​I​Gj​(v′),σjr,3)(ESIG\_{j}(v^{\\prime}),\\sigma\_{j}^{r,3}), then he sets vi≜v′v\_{i}\\triangleq v^{\\prime} and gi≜2g\_{i}\\triangleq 2. (b) Otherwise, if there exists a value v′≠⊥v^{\\prime}\\neq\\bot such that, among all the valid messages mjr,3m\_{j}^{r,3} he has received, more than 1/3 of them are of the form (E​S​I​Gj​(v′),σjr,3)(ESIG\_{j}(v^{\\prime}),\\sigma\_{j}^{r,3}), then he sets vi≜v′v\_{i}\\triangleq v^{\\prime} and gi≜1g\_{i}\\triangleq 1.2222 22 It can be proved that the v′v^{\\prime} in case (b), if exists, must be unique. (c) Else, he sets vi≜H⁡(Bϵr)v\_{i}\\triangleq H(B^{r}\_{\\epsilon}) and gi≜0g\_{i}\\triangleq 0. 2. He computes bib\_{i}, the input of B​B​A⋆BBA^{\\star}, as follows: bi≜0b\_{i}\\triangleq 0 if gi\=2g\_{i}=2, and bi≜1b\_{i}\\triangleq 1 otherwise. 3. He computes the message mir,4≜(E​S​I​Gi​(bi),E​S​I​Gi​(vi),σir,4)m^{r,4}\_{i}\\triangleq(ESIG\_{i}(b\_{i}),ESIG\_{i}(v\_{i}),\\sigma^{r,4}\_{i}), destroys his ephemeral secret key s​kir,4sk^{r,4}\_{i}, and then propagates mir,4m^{r,4}\_{i}.

Step ss, 5≤s≤m+25\\leq s\\leq m+2, s−2≡0mod3s-2\\equiv 0\\mod 3: A Coin-Fixed-To-0 Step of B​B​A⋆BBA^{\\star} Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step ss of round rr as soon as he knows Br−1B^{r-1}. ∙\\bullet User ii computes Qr−1Q^{r-1} from the third component of Br−1B^{r-1} and checks whether i∈S​Vr,si\\in SV^{r,s}. ∙\\bullet If i∉S​Vr,si\\notin SV^{r,s}, then ii stops his own execution of Step ss right away. ∙\\bullet If i∈S​Vr,si\\in SV^{r,s} then he acts as follows. – He waits until an amount of time ts≜ts−1+2​λ\=(2​s−3)​λ+Λt\_{s}\\triangleq t\_{s-1}+2\\lambda=(2s-3)\\lambda+\\Lambda has passed. – Ending Condition 0: If, during such waiting and at any point of time, there exists a string v≠⊥v\\neq\\bot and a step s′s^{\\prime} such that (a) 5≤s′≤s5\\leq s^{\\prime}\\leq s, s′−2≡0mod3s^{\\prime}-2\\equiv 0\\mod 3 —that is, Step s′s^{\\prime} is a Coin-Fixed-To-0 step, (b) ii has received at least tH\=2​n3+1t\_{H}=\\frac{2n}{3}+1 valid messages mjr,s′−1\=(E​S​I​Gj​(0)CLOSE,m^{r,s^{\\prime}-1}\_{j}=(ESIG\_{j}(0), OPENE​S​I​Gj​(v),σjr,s′−1)ESIG\_{j}(v),\\sigma^{r,s^{\\prime}-1}\_{j}),2323 23 Such a message from player jj is counted even if player ii has also received a message from jj signing for 1. Similar things for Ending Condition 1. As shown in the analysis, this is done to ensure that all honest users know BrB^{r} within time λ\\lambda from each other. and (c) ii has received a valid message mjr,1\=(Bjr,e​s​i​gj​(H⁡(Bjr)),σjr,1)m^{r,1}\_{j}=(B^{r}\_{j},esig\_{j}(H(B^{r}\_{j})),\\sigma^{r,1}\_{j}) with v\=H⁡(Bjr)v=H(B^{r}\_{j}), then, ii stops his own execution of Step ss (and in fact of round rr) right away without propagating anything; sets Br\=BjrB^{r}=B^{r}\_{j}; and sets his own C​E​R​TrCERT^{r} to be the set of messages mjr,s′−1m^{r,s^{\\prime}-1}\_{j} of sub-step (b).2424 24 User ii now knows BrB^{r} and his own round rr finishes. He still helps propagating messages as a generic user, but does not initiate any propagation as a (r,s)(r,s)\-verifier. In particular, he has helped propagating all messages in his C​E​R​TrCERT^{r}, which is enough for our protocol. Note that he should also set bi≜0b\_{i}\\triangleq 0 for the binary BA protocol, but bib\_{i} is not needed in this case anyway. Similar things for all future instructions. – Ending Condition 1: If, during such waiting and at any point of time, there exists a step s′s^{\\prime} such that (a’) 6≤s′≤s6\\leq s^{\\prime}\\leq s, s′−2≡1mod3s^{\\prime}-2\\equiv 1\\mod 3 —that is, Step s′s^{\\prime} is a Coin-Fixed-To-1 step, and (b’) ii has received at least tHt\_{H} valid messages mjr,s′−1\=(E​S​I​Gj​(1),E​S​I​Gj​(vj)CLOSE,m^{r,s^{\\prime}-1}\_{j}=(ESIG\_{j}(1),ESIG\_{j}(v\_{j}), OPENσjr,s′−1)\\sigma^{r,s^{\\prime}-1}\_{j}),2525 25 In this case, it does not matter what the vjv\_{j}’s are. then, ii stops his own execution of Step ss (and in fact of round rr) right away without propagating anything; sets Br\=BϵrB^{r}=B^{r}\_{\\epsilon}; and sets his own C​E​R​TrCERT^{r} to be the set of messages mjr,s′−1m^{r,s^{\\prime}-1}\_{j} of sub-step (b’). – Otherwise, at the end of the wait, user ii does the following. He sets viv\_{i} to be the majority vote of the vjv\_{j}’s in the second components of all the valid mjr,s−1m^{r,s-1}\_{j}’s he has received. He computes bib\_{i} as follows. If more than 2/3 of all the valid mjr,s−1m^{r,s-1}\_{j}’s he has received are of the form (E​S​I​Gj​(0),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(0),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he sets bi≜0b\_{i}\\triangleq 0. Else, if more than 2/3 of all the valid mjr,s−1m^{r,s-1}\_{j}’s he has received are of the form (E​S​I​Gj​(1),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(1),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he sets bi≜1b\_{i}\\triangleq 1. Else, he sets bi≜0b\_{i}\\triangleq 0. He computes the message mir,s≜(E​S​I​Gi​(bi),E​S​I​Gi​(vi),σir,s)m^{r,s}\_{i}\\triangleq(ESIG\_{i}(b\_{i}),ESIG\_{i}(v\_{i}),\\sigma^{r,s}\_{i}), destroys his ephemeral secret key s​kir,ssk^{r,s}\_{i}, and then propagates mir,sm^{r,s}\_{i}.

Step ss, 6≤s≤m+26\\leq s\\leq m+2, s−2≡1mod3s-2\\equiv 1\\mod 3: A Coin-Fixed-To-1 Step of B​B​A⋆BBA^{\\star} Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step ss of round rr as soon as he knows Br−1B^{r-1}. • User ii computes Qr−1Q^{r-1} from the third component of Br−1B^{r-1} and checks whether i∈S​Vr,si\\in SV^{r,s} or not. • If i∉S​Vr,si\\notin SV^{r,s}, then ii stops his own execution of Step ss right away. • If i∈S​Vr,si\\in SV^{r,s} then he does the follows. – He waits until an amount of time ts≜(2​s−3)​λ+Λt\_{s}\\triangleq(2s-3)\\lambda+\\Lambda has passed. – Ending Condition 0: The same instructions as Coin-Fixed-To-0 steps. – Ending Condition 1: The same instructions as Coin-Fixed-To-0 steps. – Otherwise, at the end of the wait, user ii does the following. He sets viv\_{i} to be the majority vote of the vjv\_{j}’s in the second components of all the valid mjr,s−1m^{r,s-1}\_{j}’s he has received. He computes bib\_{i} as follows. If more than 2/3 of all the valid mjr,s−1m^{r,s-1}\_{j}’s he has received are of the form (E​S​I​Gj​(0),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(0),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he sets bi≜0b\_{i}\\triangleq 0. Else, if more than 2/3 of all the valid mjr,s−1m^{r,s-1}\_{j}’s he has received are of the form (E​S​I​Gj​(1),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(1),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he sets bi≜1b\_{i}\\triangleq 1. Else, he sets bi≜1b\_{i}\\triangleq 1. He computes the message mir,s≜(E​S​I​Gi​(bi),E​S​I​Gi​(vi),σir,s)m^{r,s}\_{i}\\triangleq(ESIG\_{i}(b\_{i}),ESIG\_{i}(v\_{i}),\\sigma^{r,s}\_{i}), destroys his ephemeral secret key s​kir,ssk^{r,s}\_{i}, and then propagates mir,sm^{r,s}\_{i}.

Step ss, 7≤s≤m+27\\leq s\\leq m+2, s−2≡2mod3s-2\\equiv 2\\mod 3: A Coin-Genuinely-Flipped Step of B​B​A⋆BBA^{\\star} Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step ss of round rr as soon as he knows Br−1B^{r-1}. • User ii computes Qr−1Q^{r-1} from the third component of Br−1B^{r-1} and checks whether i∈S​Vr,si\\in SV^{r,s} or not. • If i∉S​Vr,si\\notin SV^{r,s}, then ii stops his own execution of Step ss right away. • If i∈S​Vr,si\\in SV^{r,s} then he does the follows. – He waits until an amount of time ts≜(2​s−3)​λ+Λt\_{s}\\triangleq(2s-3)\\lambda+\\Lambda has passed. – Ending Condition 0: The same instructions as Coin-Fixed-To-0 steps. – Ending Condition 1: The same instructions as Coin-Fixed-To-0 steps. – Otherwise, at the end of the wait, user ii does the following. He sets viv\_{i} to be the majority vote of the vjv\_{j}’s in the second components of all the valid mjr,s−1m^{r,s-1}\_{j}’s he has received. He computes bib\_{i} as follows. If more than 2/3 of all the valid mjr,s−1m^{r,s-1}\_{j}’s he has received are of the form (E​S​I​Gj​(0),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(0),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he sets bi≜0b\_{i}\\triangleq 0. Else, if more than 2/3 of all the valid mjr,s−1m^{r,s-1}\_{j}’s he has received are of the form (E​S​I​Gj​(1),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(1),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he sets bi≜1b\_{i}\\triangleq 1. Else, let S​Vir,s−1SV^{r,s-1}\_{i} be the set of (r,s−1)(r,s-1)\-verifiers from whom he has received a valid message mjr,s−1m^{r,s-1}\_{j}. He sets bi≜𝚕𝚜𝚋⁡(minj∈SVir,s−1⁡H⁡(σjr,s−1))b\_{i}\\triangleq\\lsb(\\min\_{j\\in SV^{r,s-1}\_{i}}H(\\sigma^{r,s-1}\_{j})). He computes the message mir,s≜(E​S​I​Gi​(bi),E​S​I​Gi​(vi),σir,s)m^{r,s}\_{i}\\triangleq(ESIG\_{i}(b\_{i}),ESIG\_{i}(v\_{i}),\\sigma^{r,s}\_{i}), destroys his ephemeral secret key s​kir,ssk^{r,s}\_{i}, and then propagates mir,sm^{r,s}\_{i}.

Step m+3m+3: The Last Step of B​B​A⋆BBA^{\\star} 2626 26 With overwhelming probability B​B​A⋆BBA^{\\star} has ended before this step, and we specify this step for completeness. Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step m+3m+3 of round rr as soon as he knows Br−1B^{r-1}. • User ii computes Qr−1Q^{r-1} from the third component of Br−1B^{r-1} and checks whether i∈S​Vr,m+3i\\in SV^{r,m+3} or not. • If i∉S​Vr,m+3i\\notin SV^{r,m+3}, then ii stops his own execution of Step m+3m+3 right away. • If i∈S​Vr,m+3i\\in SV^{r,m+3} then he does the follows. – He waits until an amount of time tm+3≜tm+2+2​λ\=(2​m+3)​λ+Λt\_{m+3}\\triangleq t\_{m+2}+2\\lambda=(2m+3)\\lambda+\\Lambda has passed. – Ending Condition 0: The same instructions as Coin-Fixed-To-0 steps. – Ending Condition 1: The same instructions as Coin-Fixed-To-0 steps. – Otherwise, at the end of the wait, user ii does the following. He sets o​u​ti≜1out\_{i}\\triangleq 1 and Br≜BϵrB^{r}\\triangleq B^{r}\_{\\epsilon}. He computes the message mir,m+3\=(E​S​I​Gi​(o​u​ti),E​S​I​Gi​(H⁡(Br)),σir,m+3)m^{r,m+3}\_{i}=(ESIG\_{i}(out\_{i}),ESIG\_{i}(H(B^{r})),\\sigma^{r,m+3}\_{i}), destroys his ephemeral secret key s​kir,m+3sk^{r,m+3}\_{i}, and then propagates mir,m+3m^{r,m+3}\_{i} to certify BrB^{r}.2727 27 A certificate from Step m+3m+3 does not have to include E​S​I​Gi​(o​u​ti)ESIG\_{i}(out\_{i}). We include it for uniformity only: the certificates now have a uniform format no matter in which step they are generated.

Reconstruction of the Round-rr Block by Non-Verifiers Instructions for every user ii in the system: User ii starts his own round rr as soon as he knows Br−1B^{r-1}, and waits for block information as follows. – If, during such waiting and at any point of time, there exists a string vv and a step s′s^{\\prime} such that (a) 5≤s′≤m+35\\leq s^{\\prime}\\leq m+3 with s′−2≡0mod3s^{\\prime}-2\\equiv 0\\mod 3, (b) ii has received at least tHt\_{H} valid messages mjr,s′−1\=(E​S​I​Gj​(0),E​S​I​Gj​(v),σjr,s′−1)m^{r,s^{\\prime}-1}\_{j}=(ESIG\_{j}(0),ESIG\_{j}(v),\\sigma^{r,s^{\\prime}-1}\_{j}), and (c) ii has received a valid message mjr,1\=(Bjr,e​s​i​gj​(H⁡(Bjr)),σjr,1)m^{r,1}\_{j}=(B^{r}\_{j},esig\_{j}(H(B^{r}\_{j})),\\sigma^{r,1}\_{j}) with v\=H⁡(Bjr)v=H(B^{r}\_{j}), then, ii stops his own execution of round rr right away; sets Br\=BjrB^{r}=B^{r}\_{j}; and sets his own C​E​R​TrCERT^{r} to be the set of messages mjr,s′−1m^{r,s^{\\prime}-1}\_{j} of sub-step (b). – If, during such waiting and at any point of time, there exists a step s′s^{\\prime} such that (a’) 6≤s′≤m+36\\leq s^{\\prime}\\leq m+3 with s′−2≡1mod3s^{\\prime}-2\\equiv 1\\mod 3, and (b’) ii has received at least tHt\_{H} valid messages mjr,s′−1\=(E​S​I​Gj​(1),E​S​I​Gj​(vj),σjr,s′−1)m^{r,s^{\\prime}-1}\_{j}=(ESIG\_{j}(1),ESIG\_{j}(v\_{j}),\\sigma^{r,s^{\\prime}-1}\_{j}), then, ii stops his own execution of round rr right away; sets Br\=BϵrB^{r}=B^{r}\_{\\epsilon}; and sets his own C​E​R​TrCERT^{r} to be the set of messages mjr,s′−1m^{r,s^{\\prime}-1}\_{j} of sub-step (b’). – If, during such waiting and at any point of time, ii has received at least tHt\_{H} valid messages mjr,m+3\=(E​S​I​Gj​(1),E​S​I​Gj​(H⁡(Bϵr)),σjr,m+3)m^{r,m+3}\_{j}=(ESIG\_{j}(1),ESIG\_{j}(H(B^{r}\_{\\epsilon})),\\sigma^{r,m+3}\_{j}), then ii stops his own execution of round rr right away, sets Br\=BϵrB^{r}=B^{r}\_{\\epsilon}, and sets his own C​E​R​TrCERT^{r} to be the set of messages mjr,m+3m^{r,m+3}\_{j} for 11 and H⁡(Bϵr)H(B^{r}\_{\\epsilon}).

### 5.5 Analysis of Algorand𝟏′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{1}}

We introduce the following notations for each round r≥0r\\geq 0, used in the analysis.

-   ∙\\bullet
    
    Let TrT^{r} be the time when the first honest user knows Br−1B^{r-1}.
    
-   ∙\\bullet
    
    Let Ir+1I^{r+1} be the interval \[Tr+1,Tr+1+λ\]\[T^{r+1},T^{r+1}+\\lambda\].
    

Note that T0\=0T^{0}=0 by the initialization of the protocol. For each s≥1s\\geq 1 and i∈S​Vr,si\\in SV^{r,s}, recall that αir,s\\alpha^{r,s}\_{i} and βir,s\\beta^{r,s}\_{i} are respectively the starting time and the ending time of player ii’s step ss. Moreover, recall that ts\=(2​s−3)​λ+Λt\_{s}=(2s-3)\\lambda+\\Lambda for each 2≤s≤m+32\\leq s\\leq m+3. In addition, let I0≜{0}I^{0}\\triangleq\\{0\\} and t1≜0t\_{1}\\triangleq 0.

Finally, recall that Lr≤m/3L^{r}\\leq m/3 is a random variable representing the number of Bernoulli trials needed to see a 1, when each trial is 1 with probability ph2\\frac{p\_{h}}{2} and there are at most m/3m/3 trials. If all trials fail then Lr≜m/3L^{r}\\triangleq m/3.

In the analysis we ignore computation time, as it is in fact negligible relative to the time needed to propagate messages. In any case, by using slightly larger λ\\lambda and Λ\\Lambda, the computation time can be incorporated into the analysis directly. Most of the statements below hold “with overwhelming probability,” and we may not repeatedly emphasize this fact in the analysis.

### 5.6 Main Theorem

###### Theorem 5.1.

The following properties hold with overwhelming probability for each round r≥0r\\geq 0:

-   1.
    
    All honest users agree on the same block BrB^{r}.
    
-   2.
    
    When the leader ℓr\\ell^{r} is honest, the block BrB^{r} is generated by ℓr\\ell^{r}, BrB^{r} contains a maximal payset received by ℓr\\ell^{r} by time αℓrr,1\\alpha^{r,1}\_{\\ell^{r}}, Tr+1≤Tr+8​λ+ΛT^{r+1}\\leq T^{r}+8\\lambda+\\Lambda and all honest users know BrB^{r} in the time interval Ir+1I^{r+1}.
    
-   3.
    
    When the leader ℓr\\ell^{r} is malicious, Tr+1≤Tr+(6​Lr+10)​λ+ΛT^{r+1}\\leq T^{r}+(6L^{r}+10)\\lambda+\\Lambda and all honest users know BrB^{r} in the time interval Ir+1I^{r+1}.
    
-   4.
    
    ph\=h2​(1+h−h2)p\_{h}=h^{2}(1+h-h^{2}) for LrL^{r}, and the leader ℓr\\ell^{r} is honest with probability at least php\_{h}.
    

Before proving our main theorem, let us make two remarks.

##### Remarks.

-   •
    
    Block-Generation and True Latency. The time to generate block BrB^{r} is defined to be Tr+1−TrT^{r+1}-T^{r}. That is, it is defined to be the difference between the first time some honest user learns BrB^{r} and the first time some honest user learns Br−1B^{r-1}. When the round-rr leader is honest, Property 2 our main theorem guarantees that the exact time to generate BrB^{r} is 8​λ+Λ8\\lambda+\\Lambda time, no matter what the precise value of h\>2/3h>2/3 may be. When the leader is malicious, Property 3 implies that the expected time to generate BrB^{r} is upperbounded by (12ph+10)​λ+Λ(\\frac{12}{p\_{h}}+10)\\lambda+\\Lambda, again no matter the precise value of hh.2828 28 Indeed, 𝔼⁡\[Tr+1−Tr\]≤(6​𝔼​\[Lr\]+10)​λ+Λ\=(6⋅2ph+10)​λ+Λ\=(12ph+10)​λ+Λ\\mathbb{E}\[T^{r+1}-T^{r}\]\\leq(6\\mathbb{E}\[L^{r}\]+10)\\lambda+\\Lambda=(6\\cdot\\frac{2}{p\_{h}}+10)\\lambda+\\Lambda=(\\frac{12}{p\_{h}}+10)\\lambda+\\Lambda. However, the expected time to generate BrB^{r} depends on the precise value of hh. Indeed, by Property 4, ph\=h2​(1+h−h2)p\_{h}=h^{2}(1+h-h^{2}) and the leader is honest with probability at least php\_{h}, thus
    
    𝔼⁡\[Tr+1−Tr\]≤h2​(1+h−h2)⋅(8​λ+Λ)+(1−h2​(1+h−h2))​((12h2​(1+h−h2)+10)​λ+Λ).\\mathbb{E}\[T^{r+1}-T^{r}\]\\leq h^{2}(1+h-h^{2})\\cdot(8\\lambda+\\Lambda)+(1-h^{2}(1+h-h^{2}))((\\frac{12}{h^{2}(1+h-h^{2})}+10)\\lambda+\\Lambda).
    
    For instance, if h\=80%h=80\\%, then 𝔼⁡\[Tr+1−Tr\]≤12.7​λ+Λ.\\mathbb{E}\[T^{r+1}-T^{r}\]\\leq 12.7\\lambda+\\Lambda.
    
-   •
    
    λ\\lambda vs. Λ\\Lambda. Note that the size of the messages sent by the verifiers in a step Algorand′\\text{{Algorand}}\\,^{\\prime} is dominated by the length of the digital signature keys, which can remain fixed, even when the number of users is enormous. Also note that, in any step s\>1s>1, the same expected number nn of verifiers can be used whether the number of users is 100K, 100M, or 100M. This is so because nn solely depends on hh and FF. In sum, therefore, barring a sudden need to increase secret key length, the value of λ\\lambda should remain the same no matter how large the number of users may be in the foreseeable future.
    
    By contrast, for any transaction rate, the number of transactions grows with the number of users. Therefore, to process all new transactions in a timely fashion, the size of a block should also grow with the number of users, causing Λ\\Lambda to grow too. Thus, in the long run, we should have λ<<Λ\\lambda<<\\Lambda. Accordingly, it is proper to have a larger coefficient for λ\\lambda, and actually a coefficient of 1 for Λ\\Lambda.
    

###### Proof of Theorem [5.1](#S5.Thmtheorem1 "Theorem 5.1. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND").

We prove Properties 1–3 by induction: assuming they hold for round r−1r-1 (without loss of generality, they automatically hold for “round -1” when r\=0r=0), we prove them for round rr.

Since Br−1B^{r-1} is uniquely defined by the inductive hypothesis, the set S​Vr,sSV^{r,s} is uniquely defined for each step ss of round rr. By the choice of n1n\_{1}, S​Vr,1≠∅SV^{r,1}\\neq\\emptyset with overwhelming probability. We now state the following two lemmas, proved in Sections [5.7](#S5.SS7 "5.7 The Completeness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") and [5.8](#S5.SS8 "5.8 The Soundness Lemma ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"). Throughout the induction and in the proofs of the two lemmas, the analysis for round 0 is almost the same as the inductive step, and we will highlight the differences when they occur.

###### Lemma 5.2.

\[Completeness Lemma\] Assuming Properties 1–3 hold for round r−1r-1, when the leader ℓr\\ell^{r} is honest, with overwhelming probability,

-   ∙\\bullet
    
    All honest users agree on the same block BrB^{r}, which is generated by ℓr\\ell^{r} and contains a maximal payset received by ℓr\\ell^{r} by time αℓrr,1∈Ir\\alpha^{r,1}\_{\\ell^{r}}\\in I^{r}; and
    
-   ∙\\bullet
    
    Tr+1≤Tr+8​λ+ΛT^{r+1}\\leq T^{r}+8\\lambda+\\Lambda and all honest users know BrB^{r} in the time interval Ir+1I^{r+1}.
    

###### Lemma 5.3.

\[Soundness Lemma\] Assuming Properties 1–3 hold for round r−1r-1, when the leader ℓr\\ell^{r} is malicious, with overwhelming probability, all honest users agree on the same block BrB^{r}, Tr+1≤Tr+(6​Lr+10)​λ+ΛT^{r+1}\\leq T^{r}+(6L^{r}+10)\\lambda+\\Lambda and all honest users know BrB^{r} in the time interval Ir+1I^{r+1}.

Properties 1–3 hold by applying Lemmas [5.2](#S5.Thmtheorem2 "Lemma 5.2. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") and [5.3](#S5.Thmtheorem3 "Lemma 5.3. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") to r\=0r=0 and to the inductive step. Finally, we restate Property 4 as the following lemma, proved in Section [5.9](#S5.SS9 "5.9 Security of the Seed 𝑸^𝒓 and Probability of An Honest Leader ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND").

###### Lemma 5.4.

Given Properties 1–3 for each round before rr, ph\=h2​(1+h−h2)p\_{h}=h^{2}(1+h-h^{2}) for LrL^{r}, and the leader ℓr\\ell^{r} is honest with probability at least php\_{h}.

Combining the above three lemmas together, Theorem [5.1](#S5.Thmtheorem1 "Theorem 5.1. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") holds. ■\\blacksquare

The lemma below states several important properties about round rr given the inductive hypothesis, and will be used in the proofs of the above three lemmas.

###### Lemma 5.5.

Assume Properties 1–3 hold for round r−1r-1. For each step s≥1s\\geq 1 of round rr and each honest verifier i∈H​S​Vr,si\\in HSV^{r,s}, we have that

-   (a)
    
    αir,s∈Ir\\alpha^{r,s}\_{i}\\in I^{r};
    
-   (b)
    
    if player ii has waited an amount of time tst\_{s}, then βir,s∈\[Tr+ts,Tr+λ+ts\]\\beta^{r,s}\_{i}\\in\[T^{r}+t\_{s},T^{r}+\\lambda+t\_{s}\] for r\>0r>0 and βir,s\=ts\\beta^{r,s}\_{i}=t\_{s} for r\=0r=0; and
    
-   (c)
    
    if player ii has waited an amount of time tst\_{s}, then by time βir,s\\beta^{r,s}\_{i}, he has received all messages sent by all honest verifiers j∈H​S​Vr,s′j\\in HSV^{r,s^{\\prime}} for all steps s′<ss^{\\prime}<s.
    

Moreover, for each step s≥3s\\geq 3, we have that

-   (d)
    
    there do not exist two different players i,i′∈S​Vr,si,i^{\\prime}\\in SV^{r,s} and two different values v,v′v,v^{\\prime} of the same length, such that both players have waited an amount of time tst\_{s}, more than 2/3 of all the valid messages mjr,s−1m^{r,s-1}\_{j} player ii receives have signed for vv, and more than 2/3 of all the valid messages mjr,s−1m^{r,s-1}\_{j} player i′i^{\\prime} receives have signed for v′v^{\\prime}.
    

###### Proof.

Property (a) follows directly from the inductive hypothesis, as player ii knows Br−1B^{r-1} in the time interval IrI^{r} and starts his own step ss right away. Property (b) follows directly from (a): since player ii has waited an amount of time tst\_{s} before acting, βir,s\=αir,s+ts\\beta^{r,s}\_{i}=\\alpha^{r,s}\_{i}+t\_{s}. Note that αir,s\=0\\alpha^{r,s}\_{i}=0 for r\=0r=0.

We now prove Property (c). If s\=2s=2, then by Property (b), for all verifiers j∈H​S​Vr,1j\\in HSV^{r,1} we have

βir,s\=αir,s+ts≥Tr+ts\=Tr+λ+Λ≥βjr,1+Λ.\\beta^{r,s}\_{i}=\\alpha^{r,s}\_{i}+t\_{s}\\geq T^{r}+t\_{s}=T^{r}+\\lambda+\\Lambda\\geq\\beta^{r,1}\_{j}+\\Lambda.

Since each verifier j∈H​S​Vr,1j\\in HSV^{r,1} sends his message at time βjr,1\\beta^{r,1}\_{j} and the message reaches all honest users in at most Λ\\Lambda time, by time βir,s\\beta^{r,s}\_{i} player ii has received the messages sent by all verifiers in H​S​Vr,1HSV^{r,1} as desired.

If s\>2s>2, then ts\=ts−1+2​λt\_{s}=t\_{s-1}+2\\lambda. By Property (b), for all steps s′<ss^{\\prime}<s and all verifiers j∈H​S​Vr,s′j\\in HSV^{r,s^{\\prime}},

βir,s\=αir,s+ts≥Tr+ts\=Tr+ts−1+2​λ≥Tr+ts′+2​λ\=Tr+λ+ts′+λ≥βjr,s′+λ.\\beta^{r,s}\_{i}=\\alpha^{r,s}\_{i}+t\_{s}\\geq T^{r}+t\_{s}=T^{r}+t\_{s-1}+2\\lambda\\geq T^{r}+t\_{s^{\\prime}}+2\\lambda=T^{r}+\\lambda+t\_{s^{\\prime}}+\\lambda\\geq\\beta^{r,s^{\\prime}}\_{j}+\\lambda.

Since each verifier j∈H​S​Vr,s′j\\in HSV^{r,s^{\\prime}} sends his message at time βjr,s′\\beta^{r,s^{\\prime}}\_{j} and the message reaches all honest users in at most λ\\lambda time, by time βir,s\\beta^{r,s}\_{i} player ii has received all messages sent by all honest verifiers in H​S​Vr,s′HSV^{r,s^{\\prime}} for all s′<ss^{\\prime}<s. Thus Property (c) holds.

Finally, we prove Property (d). Note that the verifiers j∈S​Vr,s−1j\\in SV^{r,s-1} sign at most two things in Step s−1s-1 using their ephemeral secret keys: a value vjv\_{j} of the same length as the output of the hash function, and also a bit bj∈{0,1}b\_{j}\\in\\{0,1\\} if s−1≥4s-1\\geq 4. That is why in the statement of the lemma we require that vv and v′v^{\\prime} have the same length: many verifiers may have signed both a hash value vv and a bit bb, thus both pass the 2/32/3 threshold.

Assume for the sake of contradiction that there exist the desired verifiers i,i′i,i^{\\prime} and values v,v′v,v^{\\prime}. Note that some malicious verifiers in M​S​Vr,s−1MSV^{r,s-1} may have signed both vv and v′v^{\\prime}, but each honest verifier in H​S​Vr,s−1HSV^{r,s-1} has signed at most one of them. By Property (c), both ii and i′i^{\\prime} have received all messages sent by all honest verifiers in H​S​Vr,s−1HSV^{r,s-1}.

Let H​S​Vr,s−1​(v)HSV^{r,s-1}(v) be the set of honest (r,s−1)(r,s-1)\-verifiers who have signed vv, M​S​Vir,s−1MSV\_{i}^{r,s-1} the set of malicious (r,s−1)(r,s-1)\-verifiers from whom ii has received a valid message, and M​S​Vir,s−1​(v)MSV\_{i}^{r,s-1}(v) the subset of M​S​Vir,s−1MSV\_{i}^{r,s-1} from whom ii has received a valid message signing vv. By the requirements for ii and vv, we have

r​a​t​i​o≜|H​S​Vr,s−1​(v)|+|M​S​Vir,s−1​(v)||H​S​Vr,s−1|+|M​S​Vir,s−1|\>23.ratio\\triangleq\\frac{|HSV^{r,s-1}(v)|+|MSV\_{i}^{r,s-1}(v)|}{|HSV^{r,s-1}|+|MSV\_{i}^{r,s-1}|}>\\frac{2}{3}.

(1)

We first show

|M​S​Vir,s−1​(v)|≤|H​S​Vr,s−1​(v)|.|MSV\_{i}^{r,s-1}(v)|\\leq|HSV^{r,s-1}(v)|.

(2)

Assuming otherwise, by the relationships among the parameters, with overwhelming probability |H​S​Vr,s−1|\>2​|M​S​Vr,s−1|≥2​|M​S​Vir,s−1||HSV^{r,s-1}|>2|MSV^{r,s-1}|\\geq 2|MSV\_{i}^{r,s-1}|, thus

r​a​t​i​o<|H​S​Vr,s−1​(v)|+|M​S​Vir,s−1​(v)|3​|M​S​Vir,s−1|<2​|M​S​Vir,s−1​(v)|3​|M​S​Vir,s−1|≤23,ratio<\\frac{|HSV^{r,s-1}(v)|+|MSV\_{i}^{r,s-1}(v)|}{3|MSV\_{i}^{r,s-1}|}<\\frac{2|MSV\_{i}^{r,s-1}(v)|}{3|MSV\_{i}^{r,s-1}|}\\leq\\frac{2}{3},

contradicting Inequality [1](#S5.E1 "In Proof. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND").

Next, by Inequality [1](#S5.E1 "In Proof. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") we have

2​|H​S​Vr,s−1|+2|M​S​Vir,s−1|<3​|H​S​Vr,s−1​(v)|+3​|M​S​Vir,s−1​(v)|\\displaystyle 2|HSV^{r,s-1}|+2|MSV\_{i}^{r,s-1}|<3|HSV^{r,s-1}(v)|+3|MSV\_{i}^{r,s-1}(v)|

≤\\displaystyle\\leq

3​|H​S​Vr,s−1​(v)|+2​|M​S​Vir,s−1|+|M​S​Vir,s−1​(v)|.\\displaystyle 3|HSV^{r,s-1}(v)|+2|MSV\_{i}^{r,s-1}|+|MSV\_{i}^{r,s-1}(v)|.

Combining with Inequality [2](#S5.E2 "In Proof. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"),

2​|H​S​Vr,s−1|<3​|H​S​Vr,s−1​(v)|+|M​S​Vir,s−1​(v)|≤4​|H​S​Vr,s−1​(v)|,2|HSV^{r,s-1}|<3|HSV^{r,s-1}(v)|+|MSV\_{i}^{r,s-1}(v)|\\leq 4|HSV^{r,s-1}(v)|,

which implies

|H​S​Vr,s−1​(v)|\>12​|H​S​Vr,s−1|.|HSV^{r,s-1}(v)|>\\frac{1}{2}|HSV^{r,s-1}|.

Similarly, by the requirements for i′i^{\\prime} and v′v^{\\prime}, we have

|H​S​Vr,s−1​(v′)|\>12​|H​S​Vr,s−1|.|HSV^{r,s-1}(v^{\\prime})|>\\frac{1}{2}|HSV^{r,s-1}|.

Since an honest verifier j∈H​S​Vr,s−1j\\in HSV^{r,s-1} destroys his ephemeral secret key s​kjr,s−1sk^{r,s-1}\_{j} before propagating his message, the Adversary cannot forge jj’s signature for a value that jj did not sign, after learning that jj is a verifier. Thus, the two inequalities above imply |H​S​Vr,s−1|≥|H​S​Vr,s−1​(v)|+|H​S​Vr,s−1​(v′)|\>|H​S​Vr,s−1||HSV^{r,s-1}|\\geq|HSV^{r,s-1}(v)|+|HSV^{r,s-1}(v^{\\prime})|>|HSV^{r,s-1}|, a contradiction. Accordingly, the desired i,i′,v,v′i,i^{\\prime},v,v^{\\prime} do not exist, and Property (d) holds. ■\\blacksquare

### 5.7 The Completeness Lemma

Lemma [5.2](#S5.Thmtheorem2 "Lemma 5.2. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"). \[Completeness Lemma, restated\] Assuming Properties 1–3 hold for round r−1r-1, when the leader ℓr\\ell^{r} is honest, with overwhelming probability,

-   ∙\\bullet
    
    All honest users agree on the same block BrB^{r}, which is generated by ℓr\\ell^{r} and contains a maximal payset received by ℓr\\ell^{r} by time αℓrr,1∈Ir\\alpha^{r,1}\_{\\ell^{r}}\\in I^{r}; and
    
-   ∙\\bullet
    
    Tr+1≤Tr+8​λ+ΛT^{r+1}\\leq T^{r}+8\\lambda+\\Lambda and all honest users know BrB^{r} in the time interval Ir+1I^{r+1}.
    

###### Proof.

By the inductive hypothesis and Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), for each step ss and verifier i∈H​S​Vr,si\\in HSV^{r,s}, αir,s∈Ir\\alpha^{r,s}\_{i}\\in I^{r}. Below we analyze the protocol step by step.

##### Step 1.

By definition, every honest verifier i∈H​S​Vr,1i\\in HSV^{r,1} propagates the desired message mir,1m^{r,1}\_{i} at time βir,1\=αir,1\\beta^{r,1}\_{i}=\\alpha^{r,1}\_{i}, where mir,1\=(Bir,e​s​i​gi​(H⁡(Bir)),σir,1)m^{r,1}\_{i}=(B^{r}\_{i},esig\_{i}(H(B^{r}\_{i})),\\sigma^{r,1}\_{i}), Bir\=(r,P​A​Yir,S​I​Gi​(Qr−1),H⁡(Br−1))B^{r}\_{i}=(r,PAY^{r}\_{i},SIG\_{i}(Q^{r-1}),H(B^{r-1})), and P​A​YirPAY^{r}\_{i} is a maximal payset among all payments that ii has seen by time αir,1\\alpha^{r,1}\_{i}.

##### Step 2.

Arbitrarily fix an honest verifier i∈H​S​Vr,2i\\in HSV^{r,2}. By Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), when player ii is done waiting at time βir,2\=αir,2+t2\\beta^{r,2}\_{i}=\\alpha^{r,2}\_{i}+t\_{2}, he has received all messages sent by verifiers in H​S​Vr,1HSV^{r,1}, including mℓrr,1m^{r,1}\_{\\ell^{r}}. By the definition of ℓr\\ell^{r}, there does not exist another player in P​Kr−kPK^{r-k} whose credential’s hash value is smaller than H⁡(σℓrr,1)H(\\sigma^{r,1}\_{\\ell^{r}}). Of course, the Adversary can corrupt ℓr\\ell^{r} after seeing that H⁡(σℓrr,1)H(\\sigma^{r,1}\_{\\ell^{r}}) is very small, but by that time player ℓr\\ell^{r} has destroyed his ephemeral key and the message mℓrr,1m^{r,1}\_{\\ell^{r}} has been propagated. Thus verifier ii sets his own leader to be player ℓr\\ell^{r}. Accordingly, at time βir,2\\beta^{r,2}\_{i}, verifier ii propagates mir,2\=(E​S​I​Gi​(vi′),σir,2)m^{r,2}\_{i}=(ESIG\_{i}(v^{\\prime}\_{i}),\\sigma^{r,2}\_{i}), where vi′\=H⁡(Bℓrr)v^{\\prime}\_{i}=H(B^{r}\_{\\ell^{r}}). When r\=0r=0, the only difference is that βir,2\=t2\\beta^{r,2}\_{i}=t\_{2} rather than being in a range. Similar things can be said for future steps and we will not emphasize them again.

##### Step 3.

Arbitrarily fix an honest verifier i∈H​S​Vr,3i\\in HSV^{r,3}. By Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), when player ii is done waiting at time βir,3\=αir,3+t3\\beta^{r,3}\_{i}=\\alpha^{r,3}\_{i}+t\_{3}, he has received all messages sent by verifiers in H​S​Vr,2HSV^{r,2}.

By the relationships among the parameters, with overwhelming probability |H​S​Vr,2|\>2​|M​S​Vr,2||HSV^{r,2}|>2|MSV^{r,2}|. Moreover, no honest verifier would sign contradicting messages, and the Adversary cannot forge a signature of an honest verifier after the latter has destroyed his corresponding ephemeral secret key. Thus more than 2/32/3 of all the valid (r,2)(r,2)\-messages ii has received are from honest verifiers and of the form mjr,2\=(E​S​I​Gj​(H⁡(Bℓrr)),σjr,2)m^{r,2}\_{j}=(ESIG\_{j}(H(B^{r}\_{\\ell^{r}})),\\sigma^{r,2}\_{j}), with no contradiction.

Accordingly, at time βir,3\\beta^{r,3}\_{i} player ii propagates mir,3\=(E​S​I​Gi​(v′),σir,3)m^{r,3}\_{i}=(ESIG\_{i}(v^{\\prime}),\\sigma^{r,3}\_{i}), where v′\=H⁡(Bℓrr)v^{\\prime}=H(B^{r}\_{\\ell^{r}}).

##### Step 4.

Arbitrarily fix an honest verifier i∈H​S​Vr,4i\\in HSV^{r,4}. By Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), player ii has received all messages sent by verifiers in H​S​Vr,3HSV^{r,3} when he is done waiting at time βir,4\=αir,4+t4\\beta^{r,4}\_{i}=\\alpha^{r,4}\_{i}+t\_{4}. Similar to Step 3, more than 2/32/3 of all the valid (r,3)(r,3)\-messages ii has received are from honest verifiers and of the form mjr,3\=(E​S​I​Gj​(H⁡(Bℓrr)),σjr,3)m^{r,3}\_{j}=(ESIG\_{j}(H(B^{r}\_{\\ell^{r}})),\\sigma^{r,3}\_{j}).

Accordingly, player ii sets vi\=H⁡(Bℓrr)v\_{i}=H(B^{r}\_{\\ell^{r}}), gi\=2g\_{i}=2 and bi\=0b\_{i}=0. At time βir,4\=αir,4+t4\\beta^{r,4}\_{i}=\\alpha^{r,4}\_{i}+t\_{4} he propagates mir,4\=(E​S​I​Gi​(0),E​S​I​Gi​(H⁡(Bℓrr)),σir,4)m^{r,4}\_{i}=(ESIG\_{i}(0),ESIG\_{i}(H(B^{r}\_{\\ell^{r}})),\\sigma^{r,4}\_{i}).

##### Step 5.

Arbitrarily fix an honest verifier i∈H​S​Vr,5i\\in HSV^{r,5}. By Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), player ii would have received all messages sent by the verifiers in H​S​Vr,4HSV^{r,4} if he has waited till time αir,5+t5\\alpha^{r,5}\_{i}+t\_{5}. Note that |H​S​Vr,4|≥tH|HSV^{r,4}|\\geq t\_{H}.2929 29 Strictly speaking, this happens with very high probability but not necessarily overwhelming. However, this probability slightly effects the running time of the protocol, but does not affect its correctness. When h\=80%h=80\\%, then |H​S​Vr,4|≥tH|HSV^{r,4}|\\geq t\_{H} with probability 1−10−81-10^{-8}. If this event does not occur, then the protocol will continue for another 3 steps. As the probability that this does not occur in two steps is negligible, the protocol will finish at Step 8. In expectation, then, the number of steps needed is almost 5. Also note that all verifiers in H​S​Vr,4HSV^{r,4} have signed for H⁡(Bℓrr)H(B^{r}\_{\\ell^{r}}).

As |M​S​Vr,4|<tH|MSV^{r,4}|<t\_{H}, there does not exist any v′≠H⁡(Bℓrr)v^{\\prime}\\neq H(B^{r}\_{\\ell^{r}}) that could have been signed by tHt\_{H} verifiers in S​Vr,4SV^{r,4} (who would necessarily be malicious), so player ii does not stop before he has received tHt\_{H} valid messages mjr,4\=(E​S​I​Gj​(0),E​S​I​Gj​(H⁡(Bℓrr)),σjr,4)m^{r,4}\_{j}=(ESIG\_{j}(0),ESIG\_{j}(H(B^{r}\_{\\ell^{r}})),\\sigma^{r,4}\_{j}). Let TT be the time when the latter event happens. Some of those messages may be from malicious players, but because |M​S​Vr,4|<tH|MSV^{r,4}|<t\_{H}, at least one of them is from an honest verifier in H​S​Vr,4HSV^{r,4} and is sent after time Tr+t4T^{r}+t\_{4}. Accordingly, T≥Tr+t4\>Tr+λ+Λ≥βℓrr,1+ΛT\\geq T^{r}+t\_{4}>T^{r}+\\lambda+\\Lambda\\geq\\beta^{r,1}\_{\\ell^{r}}+\\Lambda, and by time TT player ii has also received the message mℓrr,1m^{r,1}\_{\\ell^{r}}. By the construction of the protocol, player ii stops at time βir,5\=T\\beta^{r,5}\_{i}=T without propagating anything; sets Br\=BℓrrB^{r}=B^{r}\_{\\ell^{r}}; and sets his own C​E​R​TrCERT^{r} to be the set of (r,4)(r,4)\-messages for 00 and H⁡(Bℓrr)H(B^{r}\_{\\ell^{r}}) that he has received.

##### Step s\>5s>5.

Similarly, for any step s\>5s>5 and any verifier i∈H​S​Vr,si\\in HSV^{r,s}, player ii would have received all messages sent by the verifiers in H​S​Vr,4HSV^{r,4} if he has waited till time αir,s+ts\\alpha^{r,s}\_{i}+t\_{s}. By the same analysis, player ii stops without propagating anything, setting Br\=BℓrrB^{r}=B^{r}\_{\\ell^{r}} (and setting his own C​E​R​TrCERT^{r} properly). Of course, the malicious verifiers may not stop and may propagate arbitrary messages, but because |M​S​Vr,s|<tH|MSV^{r,s}|<t\_{H}, by induction no other v′v^{\\prime} could be signed by tHt\_{H} verifiers in any step 4≤s′<s4\\leq s^{\\prime}<s, thus the honest verifiers only stop because they have received tHt\_{H} valid (r,4)(r,4)\-messages for 00 and H⁡(Bℓrr)H(B^{r}\_{\\ell^{r}}).

##### Reconstruction of the Round-rr Block.

The analysis of Step 5 applies to a generic honest user ii almost without any change. Indeed, player ii starts his own round rr in the interval IrI^{r} and will only stop at a time TT when he has received tHt\_{H} valid (r,4)(r,4)\-messages for H⁡(Bℓrr)H(B^{r}\_{\\ell^{r}}). Again because at least one of those messages are from honest verifiers and are sent after time Tr+t4T^{r}+t\_{4}, player ii has also received mℓrr,1m^{r,1}\_{\\ell^{r}} by time TT. Thus he sets Br\=BℓrrB^{r}=B^{r}\_{\\ell^{r}} with the proper C​E​R​TrCERT^{r}.

It only remains to show that all honest users finish their round rr within the time interval Ir+1I^{r+1}. By the analysis of Step 5, every honest verifier i∈H​S​Vr,5i\\in HSV^{r,5} knows BrB^{r} on or before αir,5+t5≤Tr+λ+t5\=Tr+8​λ+Λ\\alpha^{r,5}\_{i}+t\_{5}\\leq T^{r}+\\lambda+t\_{5}=T^{r}+8\\lambda+\\Lambda. Since Tr+1T^{r+1} is the time when the first honest user iri^{r} knows BrB^{r}, we have

Tr+1≤Tr+8​λ+ΛT^{r+1}\\leq T^{r}+8\\lambda+\\Lambda

as desired. Moreover, when player iri^{r} knows BrB^{r}, he has already helped propagating the messages in his C​E​R​TrCERT^{r}. Note that all those messages will be received by all honest users within time λ\\lambda, even if player iri^{r} were the first player to propagate them. Moreover, following the analysis above we have Tr+1≥Tr+t4≥βℓrr,1+ΛT^{r+1}\\geq T^{r}+t\_{4}\\geq\\beta^{r,1}\_{\\ell^{r}}+\\Lambda, thus all honest users have received mℓrr,1m^{r,1}\_{\\ell^{r}} by time Tr+1+λT^{r+1}+\\lambda. Accordingly, all honest users know BrB^{r} in the time interval Ir+1\=\[Tr+1,Tr+1+λ\]I^{r+1}=\[T^{r+1},T^{r+1}+\\lambda\].

Finally, for r\=0r=0 we actually have T1≤t4+λ\=6​λ+ΛT^{1}\\leq t\_{4}+\\lambda=6\\lambda+\\Lambda. Combining everything together, Lemma [5.2](#S5.Thmtheorem2 "Lemma 5.2. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") holds. ■\\blacksquare

### 5.8 The Soundness Lemma

Lemma [5.3](#S5.Thmtheorem3 "Lemma 5.3. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"). \[Soundness Lemma, restated\] Assuming Properties 1–3 hold for round r−1r-1, when the leader ℓr\\ell^{r} is malicious, with overwhelming probability, all honest users agree on the same block BrB^{r}, Tr+1≤Tr+(6​Lr+10)​λ+ΛT^{r+1}\\leq T^{r}+(6L^{r}+10)\\lambda+\\Lambda and all honest users know BrB^{r} in the time interval Ir+1I^{r+1}.

###### Proof.

We consider the two parts of the protocol, GC and B​B​A⋆BBA^{\\star}, separately.

##### GC.

By the inductive hypothesis and by Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), for any step s∈{2,3,4}s\\in\\{2,3,4\\} and any honest verifier i∈H​S​Vr,si\\in HSV^{r,s}, when player ii acts at time βir,s\=αir,s+ts\\beta^{r,s}\_{i}=\\alpha^{r,s}\_{i}+t\_{s}, he has received all messages sent by all the honest verifiers in steps s′<ss^{\\prime}<s. We distinguish two possible cases for step 4.

-   Case 1.
    
    No verifier i∈H​S​Vr,4i\\in HSV^{r,4} sets gi\=2g\_{i}=2.
    
    In this case, by definition bi\=1b\_{i}=1 for all verifiers i∈H​S​Vr,4i\\in HSV^{r,4}. That is, they start with an agreement on 11 in the binary BA protocol. They may not have an agreement on their viv\_{i}’s, but this does not matter as we will see in the binary BA.
    
-   Case 2.
    
    There exists a verifier i^∈H​S​Vr,4\\hat{i}\\in HSV^{r,4} such that gi^\=2g\_{\\hat{i}}=2.
    
    In this case, we show that
    
    -   (1)
        
        gi≥1g\_{i}\\geq 1 for all i∈H​S​Vr,4i\\in HSV^{r,4},
        
    -   (2)
        
        there exists a value v′v^{\\prime} such that vi\=v′v\_{i}=v^{\\prime} for all i∈H​S​Vr,4i\\in HSV^{r,4}, and
        
    -   (3)
        
        there exists a valid message mℓr,1m^{r,1}\_{\\ell} from some verifier ℓ∈S​Vr,1\\ell\\in SV^{r,1} such that v′\=H⁡(Bℓr)v^{\\prime}=H(B^{r}\_{\\ell}).
        
    
    Indeed, since player i^\\hat{i} is honest and sets gi^\=2g\_{\\hat{i}}=2, more than 2/32/3 of all the valid messages mjr,3m^{r,3}\_{j} he has received are for the same value v′≠⊥v^{\\prime}\\neq\\bot, and he has set vi^\=v′v\_{\\hat{i}}=v^{\\prime}.
    
    By Property (d) in Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), for any other honest (r,4)(r,4)\-verifier ii, it cannot be that more than 2/32/3 of all the valid messages mjr,3m^{r,3}\_{j} that i′i^{\\prime} has received are for the same value v′′≠v′v^{\\prime\\prime}\\neq v^{\\prime}. Accordingly, if ii sets gi\=2g\_{i}=2, it must be that ii has seen \>2/3\>2/3 majority for v′v^{\\prime} as well and set vi\=v′v\_{i}=v^{\\prime}, as desired.
    
    Now consider an arbitrary verifier i∈H​S​Vr,4i\\in HSV^{r,4} with gi<2g\_{i}<2. Similar to the analysis of Property (d) in Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), because player i^\\hat{i} has seen \>2/3\>2/3 majority for v′v^{\\prime}, more than 12​|H​S​Vr,3|\\frac{1}{2}|HSV^{r,3}| honest (r,3)(r,3)\-verifiers have signed v′v^{\\prime}. Because ii has received all messages by honest (r,3)(r,3)\-verifiers by time βir,4\=αir,4+t4\\beta^{r,4}\_{i}=\\alpha^{r,4}\_{i}+t\_{4}, he has in particular received more than 12​|H​S​Vr,3|\\frac{1}{2}|HSV^{r,3}| messages from them for v′v^{\\prime}. Because |H​S​Vr,3|\>2​|M​S​Vr,3||HSV^{r,3}|>2|MSV^{r,3}|, ii has seen \>1/3\>1/3 majority for v′v^{\\prime}. Accordingly, player ii sets gi\=1g\_{i}=1, and Property (1) holds.
    
    Does player ii necessarily set vi\=v′v\_{i}=v^{\\prime}? Assume there exists a different value v′′≠⊥v^{\\prime\\prime}\\neq\\bot such that player ii has also seen \>1/3\>1/3 majority for v′′v^{\\prime\\prime}. Some of those messages may be from malicious verifiers, but at least one of them is from some honest verifier j∈H​S​Vr,3j\\in HSV^{r,3}: indeed, because |H​S​Vr,3|\>2​|M​S​Vr,3||HSV^{r,3}|>2|MSV^{r,3}| and ii has received all messages from H​S​Vr,3HSV^{r,3}, the set of malicious verifiers from whom ii has received a valid (r,3)(r,3)\-message counts for <1/3<1/3 of all the valid messages he has received.
    
    By definition, player jj must have seen \>2/3\>2/3 majority for v′′v^{\\prime\\prime} among all the valid (r,2)(r,2)\-messages he has received. However, we already have that some other honest (r,3)(r,3)\-verifiers have seen \>2/3\>2/3 majority for v′v^{\\prime} (because they signed v′v^{\\prime}). By Property (d) of Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), this cannot happen and such a value v′′v^{\\prime\\prime} does not exist. Thus player ii must have set vi\=v′v\_{i}=v^{\\prime} as desired, and Property (2) holds.
    
    Finally, given that some honest (r,3)(r,3)\-verifiers have seen \>2/3\>2/3 majority for v′v^{\\prime}, some (actually, more than half of) honest (r,2)(r,2)\-verifiers have signed for v′v^{\\prime} and propagated their messages. By the construction of the protocol, those honest (r,2)(r,2)\-verifiers must have received a valid message mℓr,1m^{r,1}\_{\\ell} from some player ℓ∈S​Vr,1\\ell\\in SV^{r,1} with v′\=H⁡(Bℓr)v^{\\prime}=H(B^{r}\_{\\ell}), thus Property (3) holds.
    

##### 𝑩​𝑩​𝑨⋆\\bm{BBA^{\\star}}.

We again distinguish two cases.

-   Case 1.
    
    All verifiers i∈H​S​Vr,4i\\in HSV^{r,4} have bi\=1b\_{i}=1.
    
    This happens following Case 1 of GC. As |M​S​Vr,4|<tH|MSV^{r,4}|<t\_{H}, in this case no verifier in S​Vr,5SV^{r,5} could collect or generate tHt\_{H} valid (r,4)(r,4)\-messages for bit 00. Thus, no honest verifier in H​S​Vr,5HSV^{r,5} would stop because he knows a non-empty block BrB^{r}.
    
    Moreover, although there are at least tHt\_{H} valid (r,4)(r,4)\-messages for bit 11, s′\=5s^{\\prime}=5 does not satisfy s′−2≡1mod3s^{\\prime}-2\\equiv 1\\mod 3, thus no honest verifier in H​S​Vr,5HSV^{r,5} would stop because he knows Br\=BϵrB^{r}=B^{r}\_{\\epsilon}.
    
    Instead, every verifier i∈H​S​Vr,5i\\in HSV^{r,5} acts at time βir,5\=αir,5+t5\\beta^{r,5}\_{i}=\\alpha^{r,5}\_{i}+t\_{5}, by when he has received all messages sent by H​S​Vr,4HSV^{r,4} following Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"). Thus player ii has seen \>2/3\>2/3 majority for 11 and sets bi\=1b\_{i}=1.
    
    In Step 6 which is a Coin-Fixed-To-1 step, although s′\=5s^{\\prime}=5 satisfies s′−2≡0mod3s^{\\prime}-2\\equiv 0\\mod 3, there do not exist tHt\_{H} valid (r,4)(r,4)\-messages for bit 0, thus no verifier in H​S​Vr,6HSV^{r,6} would stop because he knows a non-empty block BrB^{r}. However, with s′\=6s^{\\prime}=6, s′−2≡1mod3s^{\\prime}-2\\equiv 1\\mod 3 and there do exist |H​S​Vr,5|≥tH|HSV^{r,5}|\\geq t\_{H} valid (r,5)(r,5)\-messages for bit 1 from H​S​Vr,5HSV^{r,5}.
    
    For every verifier i∈H​S​Vr,6i\\in HSV^{r,6}, following Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), on or before time αir,6+t6\\alpha^{r,6}\_{i}+t\_{6} player ii has received all messages from H​S​Vr,5HSV^{r,5}, thus ii stops without propagating anything and sets Br\=BϵrB^{r}=B^{r}\_{\\epsilon}. His C​E​R​TrCERT^{r} is the set of tHt\_{H} valid (r,5)(r,5)\-messages mjr,5\=(E​S​I​Gj​(1),E​S​I​Gj​(vj),σjr,5)m^{r,5}\_{j}=(ESIG\_{j}(1),ESIG\_{j}(v\_{j}),\\sigma^{r,5}\_{j}) received by him when he stops.
    
    Next, let player ii be either an honest verifier in a step s\>6s>6 or a generic honest user (i.e., non-verifier). Similar to the proof of Lemma [5.2](#S5.Thmtheorem2 "Lemma 5.2. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), player ii sets Br\=BϵrB^{r}=B^{r}\_{\\epsilon} and sets his own C​E​R​TrCERT^{r} to be the set of tHt\_{H} valid (r,5)(r,5)\-messages mjr,5\=(E​S​I​Gj​(1),E​S​I​Gj​(vj),σjr,5)m^{r,5}\_{j}=(ESIG\_{j}(1),ESIG\_{j}(v\_{j}),\\sigma^{r,5}\_{j}) he has received.
    
    Finally, similar to Lemma [5.2](#S5.Thmtheorem2 "Lemma 5.2. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"),
    
    Tr+1≤mini∈H​S​Vr,6⁡αir,6+t6≤Tr+λ+t6\=Tr+10​λ+Λ,T^{r+1}\\leq\\min\_{i\\in HSV^{r,6}}\\alpha^{r,6}\_{i}+t\_{6}\\leq T^{r}+\\lambda+t\_{6}=T^{r}+10\\lambda+\\Lambda,
    
    and all honest users know BrB^{r} in the time interval Ir+1I^{r+1}, because the first honest user ii who knows BrB^{r} has helped propagating the (r,5)(r,5)\-messages in his C​E​R​TrCERT^{r}.
    
-   Case 2.
    
    There exists a verifier i^∈H​S​Vr,4\\hat{i}\\in HSV^{r,4} with bi^\=0b\_{\\hat{i}}=0.
    
    This happens following Case 2 of GC and is the more complex case. By the analysis of GC, in this case there exists a valid message mℓr,1m^{r,1}\_{\\ell} such that vi\=H⁡(Bℓr)v\_{i}=H(B^{r}\_{\\ell}) for all i∈H​S​Vr,4i\\in HSV^{r,4}. Note that the verifiers in H​S​Vr,4HSV^{r,4} may not have an agreement on their bib\_{i}’s.
    
    For any step s∈{5,…,m+3}s\\in\\{5,\\dots,m+3\\} and verifier i∈H​S​Vr,si\\in HSV^{r,s}, by Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") player ii would have received all messages sent by all honest verifiers in H​S​Vr,4∪⋯∪H​S​Vr,s−1HSV^{r,4}\\cup\\cdots\\cup HSV^{r,s-1} if he has waited for time tst\_{s}.
    
    We now consider the following event EE: there exists a step s∗≥5s^{\*}\\geq 5 such that, for the first time in the binary BA, some player i∗∈S​Vr,s∗i^{\*}\\in SV^{r,s^{\*}} (whether malicious or honest) should stop without propagating anything. We use “should stop” to emphasize the fact that, if player i∗i^{\*} is malicious, then he may pretend that he should not stop according to the protocol and propagate messages of the Adversary’s choice.
    
    Moreover, by the construction of the protocol, either
    
    -   (E.aE.a)
        
        i∗i^{\*} is able to collect or generate at least tHt\_{H} valid messages mjr,s′−1\=(E​S​I​Gj​(0),E​S​I​Gj​(v)CLOSE,m^{r,s^{\\prime}-1}\_{j}=(ESIG\_{j}(0),ESIG\_{j}(v), OPENσjr,s′−1)\\sigma^{r,s^{\\prime}-1}\_{j}) for the same vv and s′s^{\\prime}, with 5≤s′≤s∗5\\leq s^{\\prime}\\leq s^{\*} and s′−2≡0mod3s^{\\prime}-2\\equiv 0\\mod 3; or
        
    -   (E.bE.b)
        
        i∗i^{\*} is able to collect or generate at least tHt\_{H} valid messages mjr,s′−1\=(E​S​I​Gj​(1),E​S​I​Gj​(vj)CLOSE,m^{r,s^{\\prime}-1}\_{j}=(ESIG\_{j}(1),ESIG\_{j}(v\_{j}), OPENσjr,s′−1)\\sigma^{r,s^{\\prime}-1}\_{j}) for the same s′s^{\\prime}, with 6≤s′≤s∗6\\leq s^{\\prime}\\leq s^{\*} and s′−2≡1mod3s^{\\prime}-2\\equiv 1\\mod 3.
        
    
    Because the honest (r,s′−1)(r,s^{\\prime}-1)\-messages are received by all honest (r,s′)(r,s^{\\prime})\-verifiers before they are done waiting in Step s′s^{\\prime}, and because the Adversary receives everything no later than the honest users, without loss of generality we have s′\=s∗s^{\\prime}=s^{\*} and player i∗i^{\*} is malicious. Note that we did not require the value vv in E.aE.a to be the hash of a valid block: as it will become clear in the analysis, v\=H⁡(Bℓr)v=H(B^{r}\_{\\ell}) in this sub-event.
    
    Below we first analyze Case 2 following event EE, and then show that the value of s∗s^{\*} is essentially distributed accordingly to LrL^{r} (thus event EE happens before Step m+3m+3 with overwhelming probability given the relationships for parameters). To begin with, for any step 5≤s<s∗5\\leq s<s^{\*}, every honest verifier i∈H​S​Vr,si\\in HSV^{r,s} has waited time tst\_{s} and set viv\_{i} to be the majority vote of the valid (r,s−1)(r,s-1)\-messages he has received. Since player ii has received all honest (r,s−1)(r,s-1)\-messages following Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), since all honest verifiers in H​S​Vr,4HSV^{r,4} have signed H⁡(Bℓr)H(B^{r}\_{\\ell}) following Case 2 of GC, and since |H​S​Vr,s−1|\>2​|M​S​Vr,s−1||HSV^{r,s-1}|>2|MSV^{r,s-1}| for each ss, by induction we have that player ii has set
    
    vi\=H⁡(Bℓr).v\_{i}=H(B^{r}\_{\\ell}).
    
    The same holds for every honest verifier i∈H​S​Vr,s∗i\\in HSV^{r,s^{\*}} who does not stop without propagating anything. Now we consider Step s∗s^{\*} and distinguish four subcases.
    
    -   Case 2.1.a.
        
        Event E.aE.a happens and there exists an honest verifier i′∈H​S​Vr,s∗i^{\\prime}\\in HSV^{r,s^{\*}} who should also stop without propagating anything.
        
        In this case, we have s∗−2≡0mod3s^{\*}-2\\equiv 0\\mod 3 and Step s∗s^{\*} is a Coin-Fixed-To-0 step. By definition, player i′i^{\\prime} has received at least tHt\_{H} valid (r,s∗−1)(r,s^{\*}-1)\-messages of the form (E​S​I​Gj​(0),E​S​I​Gj​(v),σjr,s∗−1)(ESIG\_{j}(0),ESIG\_{j}(v),\\sigma^{r,s^{\*}-1}\_{j}). Since all verifiers in H​S​Vr,s∗−1HSV^{r,s^{\*}-1} have signed H⁡(Bℓr)H(B^{r}\_{\\ell}) and |M​S​Vr,s∗−1|<tH|MSV^{r,s^{\*}-1}|<t\_{H}, we have v\=H⁡(Bℓr)v=H(B^{r}\_{\\ell}).
        
        Since at least tH−|M​S​Vr,s∗−1|≥1t\_{H}-|MSV^{r,s^{\*}-1}|\\geq 1 of the (r,s∗−1)(r,s^{\*}-1)\-messages received by i′i^{\\prime} for 00 and vv are sent by verifiers in H​S​Vr,s∗−1HSV^{r,s^{\*}-1} after time Tr+ts∗−1≥Tr+t4≥Tr+λ+Λ≥βℓr,1+ΛT^{r}+t\_{s^{\*}-1}\\geq T^{r}+t\_{4}\\geq T^{r}+\\lambda+\\Lambda\\geq\\beta^{r,1}\_{\\ell}+\\Lambda, player i′i^{\\prime} has received mℓr,1m^{r,1}\_{\\ell} by the time he receives those (r,s∗−1)(r,s^{\*}-1)\-messages. Thus player i′i^{\\prime} stops without propagating anything; sets Br\=BℓrB^{r}=B^{r}\_{\\ell}; and sets his own C​E​R​TrCERT^{r} to be the set of valid (r,s∗−1)(r,s^{\*}-1)\-messages for 0 and vv that he has received.
        
        Next, we show that, any other verifier i∈H​S​Vr,s∗i\\in HSV^{r,s^{\*}} has either stopped with Br\=BℓrB^{r}=B^{r}\_{\\ell}, or has set bi\=0b\_{i}=0 and propagated (E​S​I​Gi​(0),E​S​I​Gi​(H⁡(Bℓr)),σir,s)(ESIG\_{i}(0),ESIG\_{i}(H(B^{r}\_{\\ell})),\\sigma^{r,s}\_{i}). Indeed, because Step s∗s^{\*} is the first time some verifier should stop without propagating anything, there does not exist a step s′<s∗s^{\\prime}<s^{\*} with s′−2≡1mod3s^{\\prime}-2\\equiv 1\\mod 3 such that tHt\_{H} (r,s′−1)(r,s^{\\prime}-1)\-verifiers have signed 11. Accordingly, no verifier in H​S​Vr,s∗HSV^{r,s^{\*}} stops with Br\=BϵrB^{r}=B^{r}\_{\\epsilon}.
        
        Moreover, as all honest verifiers in steps {4,5,…,s∗−1}\\{4,5,\\dots,s^{\*}-1\\} have signed H⁡(Bℓr)H(B^{r}\_{\\ell}), there does not exist a step s′≤s∗s^{\\prime}\\leq s^{\*} with s′−2≡0mod3s^{\\prime}-2\\equiv 0\\mod 3 such that tHt\_{H} (r,s′−1)(r,s^{\\prime}-1)\-verifiers have signed some v′′≠H⁡(Bℓr)v^{\\prime\\prime}\\neq H(B^{r}\_{\\ell}) —indeed, |M​S​Vr,s′−1|<tH|MSV^{r,s^{\\prime}-1}|<t\_{H}. Accordingly, no verifier in H​S​Vr,s∗HSV^{r,s^{\*}} stops with Br≠BϵrB^{r}\\neq B^{r}\_{\\epsilon} and Br≠BℓrB^{r}\\neq B^{r}\_{\\ell}. That is, if a player i∈H​S​Vr,s∗i\\in HSV^{r,s^{\*}} has stopped without propagating anything, he must have set Br\=BℓrB^{r}=B^{r}\_{\\ell}.
        
        If a player i∈H​S​Vr,s∗i\\in HSV^{r,s^{\*}} has waited time ts∗t\_{s^{\*}} and propagated a message at time βir,s∗\=αir,s∗+ts∗\\beta^{r,s^{\*}}\_{i}=\\alpha^{r,s^{\*}}\_{i}+t\_{s^{\*}}, he has received all messages from H​S​Vr,s∗−1HSV^{r,s^{\*}-1}, including at least tH−|M​S​Vr,s∗−1|t\_{H}-|MSV^{r,s^{\*}-1}| of them for 00 and vv. If ii has seen \>2/3\>2/3 majority for 11, then he has seen more than 2​(tH−|M​S​Vr,s∗−1|)2(t\_{H}-|MSV^{r,s^{\*}-1}|) valid (r,s∗−1)(r,s^{\*}-1)\-messages for 11, with more than 2​tH−3​|M​S​Vr,s∗−1|2t\_{H}-3|MSV^{r,s^{\*}-1}| of them from honest (r,s∗−1)(r,s^{\*}-1)\-verifiers. However, this implies |H​S​Vr,s∗−1|≥tH−|M​S​Vr,s∗−1|+2​tH−3​|M​S​Vr,s∗−1|\>2​n−4​|M​S​Vr,s∗−1||HSV^{r,s^{\*}-1}|\\geq t\_{H}-|MSV^{r,s^{\*}-1}|+2t\_{H}-3|MSV^{r,s^{\*}-1}|>2n-4|MSV^{r,s^{\*}-1}|, contradicting the fact that
        
        |H​S​Vr,s∗−1|+4​|M​S​Vr,s∗−1|<2​n,|HSV^{r,s^{\*}-1}|+4|MSV^{r,s^{\*}-1}|<2n,
        
        which comes from the relationships for the parameters. Accordingly, ii does not see \>2/3\>2/3 majority for 1, and he sets bi\=0b\_{i}=0 because Step s∗s^{\*} is a Coin-Fixed-To-0 step. As we have seen, vi\=H⁡(Bℓr)v\_{i}=H(B^{r}\_{\\ell}). Thus ii propagates (E​S​I​Gi​(0),E​S​I​Gi​(H⁡(Bℓr)),σir,s)(ESIG\_{i}(0),ESIG\_{i}(H(B^{r}\_{\\ell})),\\sigma^{r,s}\_{i}) as we wanted to show.
        
        For Step s∗+1s^{\*}+1, since player i′i^{\\prime} has helped propagating the messages in his C​E​R​TrCERT^{r} on or before time αi′r,s∗+ts∗\\alpha^{r,s^{\*}}\_{i^{\\prime}}+t\_{s^{\*}}, all honest verifiers in H​S​Vr,s∗+1HSV^{r,s^{\*}+1} have received at least tHt\_{H} valid (r,s∗−1)(r,s^{\*}-1)\-messages for bit 00 and value H⁡(Bℓr)H(B^{r}\_{\\ell}) on or before they are done waiting. Furthermore, verifiers in H​S​Vr,s∗+1HSV^{r,s^{\*}+1} will not stop before receiving those (r,s∗−1)(r,s^{\*}-1)\-messages, because there do not exist any other tHt\_{H} valid (r,s′−1)(r,s^{\\prime}-1)\-messages for bit 11 with s′−2≡1mod3s^{\\prime}-2\\equiv 1\\mod 3 and 6≤s′≤s∗+16\\leq s^{\\prime}\\leq s^{\*}+1, by the definition of Step s∗s^{\*}. In particular, Step s∗+1s^{\*}+1 itself is a Coin-Fixed-To-1 step, but no honest verifier in H​S​Vr,s∗HSV^{r,s^{\*}} has propagated a message for 1, and |M​S​Vr,s∗|<tH|MSV^{r,s^{\*}}|<t\_{H}.
        
        Thus all honest verifiers in H​S​Vr,s∗+1HSV^{r,s^{\*}+1} stop without propagating anything and set Br\=BℓrB^{r}=B^{r}\_{\\ell}: as before, they have received mℓr,1m^{r,1}\_{\\ell} before they receive the desired (r,s∗−1)(r,s^{\*}-1)\-messages.3030 30 If ℓ\\ell is malicious, he might send out mℓr,1m^{r,1}\_{\\ell} late, hoping that some honest users/verifiers have not received mℓr,1m^{r,1}\_{\\ell} yet when they receive the desired certificate for it. However, since verifier i^∈H​S​Vr,4\\hat{i}\\in HSV^{r,4} has set bi^\=0b\_{\\hat{i}}=0 and vi^\=H⁡(Bℓr)v\_{\\hat{i}}=H(B^{r}\_{\\ell}), as before we have that more than half of honest verifiers i∈H​S​Vr,3i\\in HSV^{r,3} have set vi\=H⁡(Bℓr)v\_{i}=H(B^{r}\_{\\ell}). This further implies more than half of honest verifiers i∈H​S​Vr,2i\\in HSV^{r,2} have set vi\=H⁡(Bℓr)v\_{i}=H(B^{r}\_{\\ell}), and those (r,2)(r,2)\-verifiers have all received mℓr,1m^{r,1}\_{\\ell}. As the Adversary cannot distinguish a verifier from a non-verifier, he cannot target the propagation of mℓr,1m^{r,1}\_{\\ell} to (r,2)(r,2)\-verifiers without having the non-verifiers seeing it. In fact, with high probability, more than half (or a good constant fraction) of all honest users have seen mℓr,1m^{r,1}\_{\\ell} after waiting for t2t\_{2} from the beginning of their own round rr. From here on, the time λ′\\lambda^{\\prime} needed for mℓr,1m^{r,1}\_{\\ell} to reach the remaining honest users is much smaller than Λ\\Lambda, and for simplicity we do not write it out in the analysis. If 4​λ≥λ′4\\lambda\\geq\\lambda^{\\prime} then the analysis goes through without any change: by the end of Step 4, all honest users would have received mℓr,1m^{r,1}\_{\\ell}. If the size of the block becomes enormous and 4​λ<λ′4\\lambda<\\lambda^{\\prime}, then in Steps 3 and 4, the protocol could ask each verifier to wait for λ′/2\\lambda^{\\prime}/2 rather than 2​λ2\\lambda, and the analysis continues to hold. The same can be said for all honest verifiers in future steps and all honest users in general. In particular, they all know Br\=BℓrB^{r}=B^{r}\_{\\ell} within the time interval Ir+1I^{r+1} and
        
        Tr+1≤αi′r,s∗+ts∗≤Tr+λ+ts∗.T^{r+1}\\leq\\alpha^{r,s^{\*}}\_{i^{\\prime}}+t\_{s^{\*}}\\leq T^{r}+\\lambda+t\_{s^{\*}}.
        
    -   Case 2.1.b.
        
        Event E.bE.b happens and there exists an honest verifier i′∈H​S​Vr,s∗i^{\\prime}\\in HSV^{r,s^{\*}} who should also stop without propagating anything.
        
        In this case we have s∗−2≡1mod3s^{\*}-2\\equiv 1\\mod 3 and Step s∗s^{\*} is a Coin-Fixed-To-1 step. The analysis is similar to Case 2.1.a and many details have been omitted.
        
        As before, player i′i^{\\prime} must have received at least tHt\_{H} valid (r,s∗−1)(r,s^{\*}-1)\-messages of the form (E​S​I​Gj​(1),E​S​I​Gj​(vj),σjr,s∗−1)(ESIG\_{j}(1),ESIG\_{j}(v\_{j}),\\sigma^{r,s^{\*}-1}\_{j}). Again by the definition of s∗s^{\*}, there does not exist a step 5≤s′<s∗5\\leq s^{\\prime}<s^{\*} with s′−2≡0mod3s^{\\prime}-2\\equiv 0\\mod 3, where at least tHt\_{H} (r,s′−1)(r,s^{\\prime}-1)\-verifiers have signed 0 and the same vv. Thus player i′i^{\\prime} stops without propagating anything; sets Br\=BϵrB^{r}=B^{r}\_{\\epsilon}; and sets his own C​E​R​TrCERT^{r} to be the set of valid (r,s∗−1)(r,s^{\*}-1)\-messages for bit 1 that he has received.
        
        Moreover, any other verifier i∈H​S​Vr,s∗i\\in HSV^{r,s^{\*}} has either stopped with Br\=BϵrB^{r}=B^{r}\_{\\epsilon}, or has set bi\=1b\_{i}=1 and propagated (E​S​I​Gi​(1),E​S​I​Gi​(vi),σir,s∗)(ESIG\_{i}(1),ESIG\_{i}(v\_{i}),\\sigma^{r,s^{\*}}\_{i}). Since player i′i^{\\prime} has helped propagating the (r,s∗−1)(r,s^{\*}-1)\-messages in his C​E​R​TrCERT^{r} by time αi′r,s∗+ts∗\\alpha^{r,s^{\*}}\_{i^{\\prime}}+t\_{s^{\*}}, again all honest verifiers in H​S​Vr,s∗+1HSV^{r,s^{\*}+1} stop without propagating anything and set Br\=BϵrB^{r}=B^{r}\_{\\epsilon}. Similarly, all honest users know Br\=BϵrB^{r}=B^{r}\_{\\epsilon} within the time interval Ir+1I^{r+1} and
        
        Tr+1≤αi′r,s∗+ts∗≤Tr+λ+ts∗.T^{r+1}\\leq\\alpha^{r,s^{\*}}\_{i^{\\prime}}+t\_{s^{\*}}\\leq T^{r}+\\lambda+t\_{s^{\*}}.
        
    -   Case 2.2.a.
        
        Event E.aE.a happens and there does not exist an honest verifier i′∈H​S​Vr,s∗i^{\\prime}\\in HSV^{r,s^{\*}} who should also stop without propagating anything.
        
        In this case, note that player i∗i^{\*} could have a valid C​E​R​Ti∗rCERT^{r}\_{i^{\*}} consisting of the tHt\_{H} desired (r,s∗−1)(r,s^{\*}-1)\-messages the Adversary is able to collect or generate. However, the malicious verifiers may not help propagating those messages, so we cannot conclude that the honest users will receive them in time λ\\lambda. In fact, |M​S​Vr,s∗−1||MSV^{r,s^{\*}-1}| of those messages may be from malicious (r,s∗−1)(r,s^{\*}-1)\-verifiers, who did not propagate their messages at all and only send them to the malicious verifiers in step s∗s^{\*}.
        
        Similar to Case 2.1.a, here we have s∗−2≡0mod3s^{\*}-2\\equiv 0\\mod 3, Step s∗s^{\*} is a Coin-Fixed-To-0 step, and the (r,s∗−1)(r,s^{\*}-1)\-messages in C​E​R​Ti∗rCERT^{r}\_{i^{\*}} are for bit 00 and v\=H⁡(Bℓr)v=H(B^{r}\_{\\ell}). Indeed, all honest (r,s∗−1)(r,s^{\*}-1)\-verifiers sign vv, thus the Adversary cannot generate tHt\_{H} valid (r,s∗−1)(r,s^{\*}-1)\-messages for a different v′v^{\\prime}.
        
        Moreover, all honest (r,s∗)(r,s^{\*})\-verifiers have waited time ts∗t\_{s^{\*}} and do not see \>2/3\>2/3 majority for bit 11, again because |H​S​Vr,s∗−1|+4​|M​S​Vr,s∗−1|<2​n|HSV^{r,s^{\*}-1}|+4|MSV^{r,s^{\*}-1}|<2n. Thus every honest verifier i∈H​S​Vr,s∗i\\in HSV^{r,s^{\*}} sets bi\=0b\_{i}=0, vi\=H⁡(Bℓr)v\_{i}=H(B^{r}\_{\\ell}) by the majority vote, and propagates mir,s∗\=(E​S​I​Gi​(0),E​S​I​Gi​(H⁡(Bℓr)),σir,s∗)m^{r,s^{\*}}\_{i}=(ESIG\_{i}(0),ESIG\_{i}(H(B^{r}\_{\\ell})),\\sigma^{r,s^{\*}}\_{i}) at time αir,s∗+ts∗\\alpha^{r,s^{\*}}\_{i}+t\_{s^{\*}}.
        
        Now consider the honest verifiers in Step s∗+1s^{\*}+1 (which is a Coin-Fixed-To-1 step). If the Adversary actually sends the messages in C​E​R​Ti∗rCERT^{r}\_{i^{\*}} to some of them and causes them to stop, then similar to Case 2.1.a, all honest users know Br\=BℓrB^{r}=B^{r}\_{\\ell} within the time interval Ir+1I^{r+1} and
        
        Tr+1≤Tr+λ+ts∗+1.T^{r+1}\\leq T^{r}+\\lambda+t\_{s^{\*}+1}.
        
        Otherwise, all honest verifiers in Step s∗+1s^{\*}+1 have received all the (r,s∗)(r,s^{\*})\-messages for 00 and H⁡(Bℓr)H(B^{r}\_{\\ell}) from H​S​Vr,s∗HSV^{r,s^{\*}} after waiting time ts∗+1t\_{s^{\*}+1}, which leads to \>2/3\>2/3 majority, because |H​S​Vr,s∗|\>2​|M​S​Vr,s∗||HSV^{r,s^{\*}}|>2|MSV^{r,s^{\*}}|. Thus all the verifiers in H​S​Vr,s∗+1HSV^{r,s^{\*}+1} propagate their messages for 00 and H⁡(Bℓr)H(B^{r}\_{\\ell}) accordingly. Note that the verifiers in H​S​Vr,s∗+1HSV^{r,s^{\*}+1} do not stop with Br\=BℓrB^{r}=B^{r}\_{\\ell}, because Step s∗+1s^{\*}+1 is not a Coin-Fixed-To-0 step.
        
        Now consider the honest verifiers in Step s∗+2s^{\*}+2 (which is a Coin-Genuinely-Flipped step). If the Adversary sends the messages in C​E​R​Ti∗rCERT^{r}\_{i^{\*}} to some of them and causes them to stop, then again all honest users know Br\=BℓrB^{r}=B^{r}\_{\\ell} within the time interval Ir+1I^{r+1} and
        
        Tr+1≤Tr+λ+ts∗+2.T^{r+1}\\leq T^{r}+\\lambda+t\_{s^{\*}+2}.
        
        Otherwise, all honest verifiers in Step s∗+2s^{\*}+2 have received all the (r,s∗+1)(r,s^{\*}+1)\-messages for 00 and H⁡(Bℓr)H(B^{r}\_{\\ell}) from H​S​Vr,s∗+1HSV^{r,s^{\*}+1} after waiting time ts∗+2t\_{s^{\*}+2}, which leads to \>2/3\>2/3 majority. Thus all of them propagate their messages for 00 and H⁡(Bℓr)H(B^{r}\_{\\ell}) accordingly: that is they do not “flip a coin” in this case. Again, note that they do not stop without propagating, because Step s∗+2s^{\*}+2 is not a Coin-Fixed-To-0 step.
        
        Finally, for the honest verifiers in Step s∗+3s^{\*}+3 (which is another Coin-Fixed-To-0 step), all of them would have received at least tHt\_{H} valid messages for 00 and H⁡(Bℓr)H(B^{r}\_{\\ell}) from H​S​Vs∗+2HSV^{s^{\*}+2}, if they really wait time ts∗+3t\_{s^{\*}+3}. Thus, whether or not the Adversary sends the messages in C​E​R​Ti∗rCERT^{r}\_{i^{\*}} to any of them, all verifiers in H​S​Vr,s∗+3HSV^{r,s^{\*}+3} stop with Br\=BℓrB^{r}=B^{r}\_{\\ell}, without propagating anything. Depending on how the Adversary acts, some of them may have their own C​E​R​TrCERT^{r} consisting of those (r,s∗−1)(r,s^{\*}-1)\-messages in C​E​R​Ti∗rCERT^{r}\_{i^{\*}}, and the others have their own C​E​R​TrCERT^{r} consisting of those (r,s∗+2)(r,s^{\*}+2)\-messages. In any case, all honest users know Br\=BℓrB^{r}=B^{r}\_{\\ell} within the time interval Ir+1I^{r+1} and
        
        Tr+1≤Tr+λ+ts∗+3.T^{r+1}\\leq T^{r}+\\lambda+t\_{s^{\*}+3}.
        
    -   Case 2.2.b.
        
        Event E.bE.b happens and there does not exist an honest verifier i′∈H​S​Vr,s∗i^{\\prime}\\in HSV^{r,s^{\*}} who should also stop without propagating anything.
        
        The analysis in this case is similar to those in Case 2.1.b and Case 2.2.a, thus many details have been omitted. In particular, C​E​R​Ti∗rCERT^{r}\_{i^{\*}} consists of the tHt\_{H} desired (r,s∗−1)(r,s^{\*}-1)\-messages for bit 1 that the Adversary is able to collect or generate, s∗−2≡1mod3s^{\*}-2\\equiv 1\\mod 3, Step s∗s^{\*} is a Coin-Fixed-To-1 step, and no honest (r,s∗)(r,s^{\*})\-verifier could have seen \>2/3\>2/3 majority for 00.
        
        Thus, every verifier i∈H​S​Vr,s∗i\\in HSV^{r,s^{\*}} sets bi\=1b\_{i}=1 and propagates mir,s∗\=(E​S​I​Gi​(1),E​S​I​Gi​(vi)CLOSE,m^{r,s^{\*}}\_{i}=(ESIG\_{i}(1),ESIG\_{i}(v\_{i}), OPENσir,s∗)\\sigma^{r,s^{\*}}\_{i}) at time αir,s∗+ts∗\\alpha^{r,s^{\*}}\_{i}+t\_{s^{\*}}. Similar to Case 2.2.a, in at most 3 more steps (i.e., the protocol reaches Step s∗+3s^{\*}+3, which is another Coin-Fixed-To-1 step), all honest users know Br\=BϵrB^{r}=B^{r}\_{\\epsilon} within the time interval Ir+1I^{r+1}. Moreover, Tr+1T^{r+1} may be ≤Tr+λ+ts∗+1\\leq T^{r}+\\lambda+t\_{s^{\*}+1}, or ≤Tr+λ+ts∗+2\\leq T^{r}+\\lambda+t\_{s^{\*}+2}, or ≤Tr+λ+ts∗+3\\leq T^{r}+\\lambda+t\_{s^{\*}+3}, depending on when is the first time an honest verifier is able to stop without propagating.
        
    
    Combining the four sub-cases, we have that all honest users know BrB^{r} within the time interval Ir+1I^{r+1}, with
    
    -   Tr+1≤Tr+λ+ts∗T^{r+1}\\leq T^{r}+\\lambda+t\_{s^{\*}} in Cases 2.1.a and 2.1.b, and
        
    -   Tr+1≤Tr+λ+ts∗+3T^{r+1}\\leq T^{r}+\\lambda+t\_{s^{\*}+3} in Cases 2.2.a and 2.2.b.
        
    
    It remains to upper-bound s∗s^{\*} and thus Tr+1T^{r+1} for Case 2, and we do so by considering how many times the Coin-Genuinely-Flipped steps are actually executed in the protocol: that is, some honest verifiers actually have flipped a coin.
    
    In particular, arbitrarily fix a Coin-Genuinely-Flipped step s′s^{\\prime} (i.e., 7≤s′≤m+27\\leq s^{\\prime}\\leq m+2 and s′−2≡2mod3s^{\\prime}-2\\equiv 2\\mod 3), and let ℓ′≜arg​minj∈SVr,s′−1⁡H​(σjr,s′−1)\\ell^{\\prime}\\triangleq\\argmin\_{j\\in SV^{r,s^{\\prime}-1}}H(\\sigma^{r,s^{\\prime}-1}\_{j}). For now let us assume s′<s∗s^{\\prime}<s^{\*}, because otherwise no honest verifier actually flips a coin in Step s′s^{\\prime}, according to previous discussions.
    
    By the definition of S​Vr,s′−1SV^{r,s^{\\prime}-1}, the hash value of the credential of ℓ′\\ell^{\\prime} is also the smallest among all users in P​Kr−kPK^{r-k}. Since the hash function is a random oracle, ideally player ℓ′\\ell^{\\prime} is honest with probability at least hh. As we will show later, even if the Adversary tries his best to predict the output of the random oracle and tilt the probability, player ℓ′\\ell^{\\prime} is still honest with probability at least ph\=h2​(1+h−h2)p\_{h}=h^{2}(1+h-h^{2}). Below we consider the case when that indeed happens: that is, ℓ′∈H​S​Vr,s′−1\\ell^{\\prime}\\in HSV^{r,s^{\\prime}-1}.
    
    Note that every honest verifier i∈H​S​Vr,s′i\\in HSV^{r,s^{\\prime}} has received all messages from H​S​Vr,s′−1HSV^{r,s^{\\prime}-1} by time αir,s′+ts′\\alpha^{r,s^{\\prime}}\_{i}+t\_{s^{\\prime}}. If player ii needs to flip a coin (i.e., he has not seen \>2/3\>2/3 majority for the same bit b∈{0,1}b\\in\\{0,1\\}), then he sets bi\=𝚕𝚜𝚋⁡(H⁡(σℓ′r,s′−1))b\_{i}=\\lsb(H(\\sigma^{r,s^{\\prime}-1}\_{\\ell^{\\prime}})). If there exists another honest verifier i′∈H​S​Vr,s′i^{\\prime}\\in HSV^{r,s^{\\prime}} who has seen \>2/3\>2/3 majority for a bit b∈{0,1}b\\in\\{0,1\\}, then by Property (d) of Lemma [5.5](#S5.Thmtheorem5 "Lemma 5.5. ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), no honest verifier in H​S​Vr,s′HSV^{r,s^{\\prime}} would have seen \>2/3\>2/3 majority for a bit b′≠bb^{\\prime}\\neq b. Since 𝚕𝚜𝚋⁡(H⁡(σℓ′r,s′−1))\=b\\lsb(H(\\sigma^{r,s^{\\prime}-1}\_{\\ell^{\\prime}}))=b with probability 1/21/2, all honest verifiers in H​S​Vr,s′HSV^{r,s^{\\prime}} reach an agreement on bb with probability 1/21/2. Of course, if such a verifier i′i^{\\prime} does not exist, then all honest verifiers in H​S​Vr,s′HSV^{r,s^{\\prime}} agree on the bit 𝚕𝚜𝚋⁡(H⁡(σℓ′r,s′−1))\\lsb(H(\\sigma^{r,s^{\\prime}-1}\_{\\ell^{\\prime}})) with probability 1.
    
    Combining the probability for ℓ′∈H​S​Vr,s′−1\\ell^{\\prime}\\in HSV^{r,s^{\\prime}-1}, we have that the honest verifiers in H​S​Vr,s′HSV^{r,s^{\\prime}} reach an agreement on a bit b∈{0,1}b\\in\\{0,1\\} with probability at least ph2\=h2​(1+h−h2)2\\frac{p\_{h}}{2}=\\frac{h^{2}(1+h-h^{2})}{2}. Moreover, by induction on the majority vote as before, all honest verifiers in H​S​Vr,s′HSV^{r,s^{\\prime}} have their viv\_{i}’s set to be H⁡(Bℓr)H(B^{r}\_{\\ell}). Thus, once an agreement on bb is reached in Step s′s^{\\prime}, Tr+1T^{r+1} is
    
    either ≤Tr+λ+ts′+1​ or ≤Tr+λ+ts′+2,\\mbox{either }\\leq T^{r}+\\lambda+t\_{s^{\\prime}+1}\\mbox{ or }\\leq T^{r}+\\lambda+t\_{s^{\\prime}+2},
    
    depending on whether b\=0b=0 or b\=1b=1, following the analysis of Cases 2.1.a and 2.1.b. In particular, no further Coin-Genuinely-Flipped step will be executed: that is, the verifiers in such steps still check that they are the verifiers and thus wait, but they will all stop without propagating anything. Accordingly, before Step s∗s^{\*}, the number of times the Coin-Genuinely-Flipped steps are executed is distributed according to the random variable LrL^{r}. Letting Step s′s^{\\prime} be the last Coin-Genuinely-Flipped step according to LrL^{r}, by the construction of the protocol we have
    
    s′\=4+3​Lr.s^{\\prime}=4+3L^{r}.
    
    When should the Adversary make Step s∗s^{\*} happen if he wants to delay Tr+1T^{r+1} as much as possible? We can even assume that the Adversary knows the realization of LrL^{r} in advance. If s∗\>s′s^{\*}>s^{\\prime} then it is useless, because the honest verifiers have already reached an agreement in Step s′s^{\\prime}. To be sure, in this case s∗s^{\*} would be s′+1s^{\\prime}+1 or s′+2s^{\\prime}+2, again depending on whether b\=0b=0 or b\=1b=1. However, this is actually Cases 2.1.a and 2.1.b, and the resulting Tr+1T^{r+1} is exactly the same as in that case. More precisely,
    
    Tr+1≤Tr+λ+ts∗≤Tr+λ+ts′+2.T^{r+1}\\leq T^{r}+\\lambda+t\_{s^{\*}}\\leq T^{r}+\\lambda+t\_{s^{\\prime}+2}.
    
    If s∗<s′−3s^{\*}<s^{\\prime}-3 —that is, s∗s^{\*} is before the second-last Coin-Genuinely-Flipped step— then by the analysis of Cases 2.2.a and 2.2.b,
    
    Tr+1≤Tr+λ+ts∗+3<Tr+λ+ts′.T^{r+1}\\leq T^{r}+\\lambda+t\_{s^{\*}+3}<T^{r}+\\lambda+t\_{s^{\\prime}}.
    
    That is, the Adversary is actually making the agreement on BrB^{r} happen faster.
    
    If s∗\=s′−2s^{\*}=s^{\\prime}-2 or s′−1s^{\\prime}-1 —that is, the Coin-Fixed-To-0 step or the Coin-Fixed-To-1 step immediately before Step s′s^{\\prime}— then by the analysis of the four sub-cases, the honest verifiers in Step s′s^{\\prime} do not get to flip coins anymore, because they have either stopped without propagating, or have seen \>2/3\>2/3 majority for the same bit bb. Therefore we have
    
    Tr+1≤Tr+λ+ts∗+3≤Tr+λ+ts′+2.T^{r+1}\\leq T^{r}+\\lambda+t\_{s^{\*}+3}\\leq T^{r}+\\lambda+t\_{s^{\\prime}+2}.
    
    In sum, no matter what s∗s^{\*} is, we have
    
    Tr+1≤Tr+λ+ts′+2\=Tr+λ+t3​Lr+6\\displaystyle T^{r+1}\\leq T^{r}+\\lambda+t\_{s^{\\prime}+2}=T^{r}+\\lambda+t\_{3L^{r}+6}
    
    \=\\displaystyle=
    
    Tr+λ+(2​(3​Lr+6)−3)​λ+Λ\\displaystyle T^{r}+\\lambda+(2(3L^{r}+6)-3)\\lambda+\\Lambda
    
    \=\\displaystyle=
    
    Tr+(6​Lr+10)​λ+Λ,\\displaystyle T^{r}+(6L^{r}+10)\\lambda+\\Lambda,
    
    as we wanted to show. The worst case is when s∗\=s′−1s^{\*}=s^{\\prime}-1 and Case 2.2.b happens.
    

Combining Cases 1 and 2 of the binary BA protocol, Lemma [5.3](#S5.Thmtheorem3 "Lemma 5.3. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") holds. ■\\blacksquare

### 5.9 Security of the Seed 𝑸𝒓\\bm{Q^{r}} and Probability of An Honest Leader

It remains to prove Lemma [5.4](#S5.Thmtheorem4 "Lemma 5.4. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"). Recall that the verifiers in round rr are taken from P​Kr−kPK^{r-k} and are chosen according to the quantity Qr−1Q^{r-1}. The reason for introducing the look-back parameter kk is to make sure that, back at round r−kr-k, when the Adversary is able to add new malicious users to P​Kr−kPK^{r-k}, he cannot predict the quantity Qr−1Q^{r-1} except with negligible probability. Note that the hash function is a random oracle and Qr−1Q^{r-1} is one of its inputs when selecting verifiers for round rr. Thus, no matter how malicious users are added to P​Kr−kPK^{r-k}, from the Adversary’s point of view each one of them is still selected to be a verifier in a step of round rr with the required probability pp (or p1p\_{1} for Step 1). More precisely, we have the following lemma.

###### Lemma 5.6.

With k\=O⁡(log1/2⁡F)k=O(\\log\_{1/2}F), for each round rr, with overwhelming probability the Adversary did not query Qr−1Q^{r-1} to the random oracle back at round r−kr-k.

###### Proof.

We proceed by induction. Assume that for each round γ<r\\gamma<r, the Adversary did not query Qγ−1Q^{\\gamma-1} to the random oracle back at round γ−k\\gamma-k.3131 31 As kk is a small integer, without loss of generality one can assume that the first kk rounds of the protocol are run under a safe environment and the inductive hypothesis holds for those rounds. Consider the following mental game played by the Adversary at round r−kr-k, trying to predict Qr−1Q^{r-1}.

In Step 1 of each round γ\=r−k,…,r−1\\gamma=r-k,\\dots,r-1, given a specific Qγ−1Q^{\\gamma-1} not queried to the random oracle, by ordering the players i∈P​Kγ−ki\\in PK^{\\gamma-k} according to the hash values H⁡(S​I​Gi​(γ,1,Qγ−1))H(SIG\_{i}(\\gamma,1,Q^{\\gamma-1})) increasingly, we obtain a random permutation over P​Kγ−kPK^{\\gamma-k}. By definition, the leader ℓγ\\ell^{\\gamma} is the first user in the permutation and is honest with probability hh. Moreover, when P​Kγ−kPK^{\\gamma-k} is large enough, for any integer x≥1x\\geq 1, the probability that the first xx users in the permutation are all malicious but the (x+1)(x+1)st is honest is (1−h)x​h(1-h)^{x}h.

If ℓγ\\ell^{\\gamma} is honest, then Qγ\=H⁡(S​I​Gℓγ​(Qγ−1),γ)Q^{\\gamma}=H(SIG\_{\\ell^{\\gamma}}(Q^{\\gamma-1}),\\gamma). As the Adversary cannot forge the signature of ℓγ\\ell^{\\gamma}, QγQ^{\\gamma} is distributed uniformly at random from the Adversary’s point of view and, except with exponentially small probability,3232 32 That is, exponential in the length of the output of HH. Note that this probability is way smaller than FF. was not queried to HH at round r−kr-k. Since each Qγ+1,Qγ+2,…,Qr−1Q^{\\gamma+1},Q^{\\gamma+2},\\dots,Q^{r-1} respectively is the output of HH with Qγ,Qγ+1,…,Qr−2Q^{\\gamma},Q^{\\gamma+1},\\dots,Q^{r-2} as one of the inputs, they all look random to the Adversary and the Adversary could not have queried Qr−1Q^{r-1} to HH at round r−kr-k.

Accordingly, the only case where the Adversary can predict Qr−1Q^{r-1} with good probability at round r−kr-k is when all the leaders ℓr−k,…,ℓr−1\\ell^{r-k},\\dots,\\ell^{r-1} are malicious. Again consider a round γ∈{r−k​…,r−1}\\gamma\\in\\{r-k\\dots,r-1\\} and the random permutation over P​Kγ−kPK^{\\gamma-k} induced by the corresponding hash values. If for some x≥2x\\geq 2, the first x−1x-1 users in the permutation are all malicious and the xx\-th is honest, then the Adversary has xx possible choices for QγQ^{\\gamma}: either of the form H⁡(S​I​Gi​(Qγ−1,γ))H(SIG\_{i}(Q^{\\gamma-1},\\gamma)), where ii is one of the first x−1x-1 malicious users, by making player ii the actually leader of round γ\\gamma; or H⁡(Qγ−1,γ)H(Q^{\\gamma-1},\\gamma), by forcing Bγ\=BϵγB^{\\gamma}=B^{\\gamma}\_{\\epsilon}. Otherwise, the leader of round γ\\gamma will be the first honest user in the permutation and Qr−1Q^{r-1} becomes unpredictable to the Adversary.

Which of the above xx options of QγQ^{\\gamma} should the Adversary pursue? To help the Adversary answer this question, in the mental game we actually make him more powerful than he actually is, as follows. First of all, in reality, the Adversary cannot compute the hash of a honest user’s signature, thus cannot decide, for each QγQ^{\\gamma}, the number x⁡(Qγ)x(Q^{\\gamma}) of malicious users at the beginning of the random permutation in round γ+1\\gamma+1 induced by QγQ^{\\gamma}. In the mental game, we give him the numbers x⁡(Qγ)x(Q^{\\gamma}) for free. Second of all, in reality, having the first xx users in the permutation all being malicious does not necessarily mean they can all be made into the leader, because the hash values of their signatures must also be less than p1p\_{1}. We have ignored this constraint in the mental game, giving the Adversary even more advantages.

It is easy to see that in the mental game, the optimal option for the Adversary, denoted by Q^γ\\hat{Q}^{\\gamma}, is the one that produces the longest sequence of malicious users at the beginning of the random permutation in round γ+1\\gamma+1. Indeed, given a specific QγQ^{\\gamma}, the protocol does not depend on Qγ−1Q^{\\gamma-1} anymore and the Adversary can solely focus on the new permutation in round γ+1\\gamma+1, which has the same distribution for the number of malicious users at the beginning. Accordingly, in each round γ\\gamma, the above mentioned Q^γ\\hat{Q}^{\\gamma} gives him the largest number of options for Qγ+1Q^{\\gamma+1} and thus maximizes the probability that the consecutive leaders are all malicious.

Therefore, in the mental game the Adversary is following a Markov Chain from round r−kr-k to round r−1r-1, with the state space being {0}∪{x:x≥2}\\{0\\}\\cup\\{x:x\\geq 2\\}. State 00 represents the fact that the first user in the random permutation in the current round γ\\gamma is honest, thus the Adversary fails the game for predicting Qr−1Q^{r-1}; and each state x≥2x\\geq 2 represents the fact that the first x−1x-1 users in the permutation are malicious and the xx\-th is honest, thus the Adversary has xx options for QγQ^{\\gamma}. The transition probabilities P⁡(x,y)P(x,y) are as follows.

-   ∙\\bullet
    
    P⁡(0,0)\=1P(0,0)=1 and P⁡(0,y)\=0P(0,y)=0 for any y≥2y\\geq 2. That is, the Adversary fails the game once the first user in the permutation becomes honest.
    
-   ∙\\bullet
    
    P⁡(x,0)\=hxP(x,0)=h^{x} for any x≥2x\\geq 2. That is, with probability hxh^{x}, all the xx random permutations have their first users being honest, thus the Adversary fails the game in the next round.
    
-   ∙\\bullet
    
    For any x≥2x\\geq 2 and y≥2y\\geq 2, P⁡(x,y)P(x,y) is the probability that, among the xx random permutations induced by the xx options of QγQ^{\\gamma}, the longest sequence of malicious users at the beginning of some of them is y−1y-1, thus the Adversary has yy options for Qγ+1Q^{\\gamma+1} in the next round. That is,
    
    P⁡(x,y)\=(∑i\=0y−1(1−h)i​h)x−(∑i\=0y−2(1−h)i​h)x\=(1−(1−h)y)x−(1−(1−h)y−1)x.P(x,y)=\\left(\\sum\_{i=0}^{y-1}(1-h)^{i}h\\right)^{x}-\\left(\\sum\_{i=0}^{y-2}(1-h)^{i}h\\right)^{x}=(1-(1-h)^{y})^{x}-(1-(1-h)^{y-1})^{x}.
    

Note that state 0 is the unique absorbing state in the transition matrix PP, and every other state xx has a positive probability of going to 0. We are interested in upper-bounding the number kk of rounds needed for the Markov Chain to converge to 0 with overwhelming probability: that is, no matter which state the chain starts at, with overwhelming probability the Adversary loses the game and fails to predict Qr−1Q^{r-1} at round r−kr-k.

Consider the transition matrix P(2)≜P⋅PP^{(2)}\\triangleq P\\cdot P after two rounds. It is easy to see that P(2)​(0,0)\=1P^{(2)}(0,0)=1 and P(2)​(0,x)\=0P^{(2)}(0,x)=0 for any x≥2x\\geq 2. For any x≥2x\\geq 2 and y≥2y\\geq 2, as P⁡(0,y)\=0P(0,y)=0, we have

P(2)​(x,y)\=P⁡(x,0)​P​(0,y)+∑z≥2P⁡(x,z)​P​(z,y)\=∑z≥2P⁡(x,z)​P​(z,y).P^{(2)}(x,y)=P(x,0)P(0,y)+\\sum\_{z\\geq 2}P(x,z)P(z,y)=\\sum\_{z\\geq 2}P(x,z)P(z,y).

Letting h¯≜1−h\\bar{h}\\triangleq 1-h, we have

P⁡(x,y)\=(1−h¯y)x−(1−h¯y−1)xP(x,y)=(1-\\bar{h}^{y})^{x}-(1-\\bar{h}^{y-1})^{x}

and

P(2)​(x,y)\=∑z≥2\[(1−h¯z)x−(1−h¯z−1)x\]​\[(1−h¯y)z−(1−h¯y−1)z\].P^{(2)}(x,y)=\\sum\_{z\\geq 2}\[(1-\\bar{h}^{z})^{x}-(1-\\bar{h}^{z-1})^{x}\]\[(1-\\bar{h}^{y})^{z}-(1-\\bar{h}^{y-1})^{z}\].

Below we compute the limit of P(2)​(x,y)P⁡(x,y)\\frac{P^{(2)}(x,y)}{P(x,y)} as hh goes to 11 —that is, h¯\\bar{h} goes to 0. Note that the highest order of h¯\\bar{h} in P⁡(x,y)P(x,y) is h¯y−1\\bar{h}^{y-1}, with coefficient xx. Accordingly,

limh→1P(2)​(x,y)P⁡(x,y)\=limh¯→0P(2)​(x,y)P⁡(x,y)\=limh¯→0P(2)​(x,y)x​h¯y−1+O⁡(h¯y)\\displaystyle\\lim\_{h\\rightarrow 1}\\frac{P^{(2)}(x,y)}{P(x,y)}=\\lim\_{\\bar{h}\\rightarrow 0}\\frac{P^{(2)}(x,y)}{P(x,y)}=\\lim\_{\\bar{h}\\rightarrow 0}\\frac{P^{(2)}(x,y)}{x\\bar{h}^{y-1}+O(\\bar{h}^{y})}

\=\\displaystyle=

limh¯→0∑z≥2\[x​h¯z−1+O⁡(h¯z)\]​\[z​h¯y−1+O⁡(h¯y)\]x​h¯y−1+O⁡(h¯y)\=limh¯→02​x​h¯y+O⁡(h¯y+1)x​h¯y−1+O⁡(h¯y)\\displaystyle\\lim\_{\\bar{h}\\rightarrow 0}\\frac{\\sum\_{z\\geq 2}\[x\\bar{h}^{z-1}+O(\\bar{h}^{z})\]\[z\\bar{h}^{y-1}+O(\\bar{h}^{y})\]}{x\\bar{h}^{y-1}+O(\\bar{h}^{y})}=\\lim\_{\\bar{h}\\rightarrow 0}\\frac{2x\\bar{h}^{y}+O(\\bar{h}^{y+1})}{x\\bar{h}^{y-1}+O(\\bar{h}^{y})}

\=\\displaystyle=

limh¯→02​x​h¯yx​h¯y−1\=limh¯→02​h¯\=0.\\displaystyle\\lim\_{\\bar{h}\\rightarrow 0}\\frac{2x\\bar{h}^{y}}{x\\bar{h}^{y-1}}=\\lim\_{\\bar{h}\\rightarrow 0}2\\bar{h}=0.

When hh is sufficiently close to 11,3333 33 For example, h\=80%h=80\\% as suggested by the specific choices of parameters. we have

P(2)​(x,y)P⁡(x,y)≤12\\frac{P^{(2)}(x,y)}{P(x,y)}\\leq\\frac{1}{2}

for any x≥2x\\geq 2 and y≥2y\\geq 2. By induction, for any k\>2k>2, P(k)≜PkP^{(k)}\\triangleq P^{k} is such that

-   ∙\\bullet
    
    P(k)​(0,0)\=1P^{(k)}(0,0)=1, P(k)​(0,x)\=0P^{(k)}(0,x)=0 for any x≥2x\\geq 2, and
    
-   ∙\\bullet
    
    for any x≥2x\\geq 2 and y≥2y\\geq 2,
    
    P(k)​(x,y)\=P(k−1)​(x,0)​P​(0,y)+∑z≥2P(k−1)​(x,z)​P​(z,y)\=∑z≥2P(k−1)​(x,z)​P​(z,y)\\displaystyle P^{(k)}(x,y)=P^{(k-1)}(x,0)P(0,y)+\\sum\_{z\\geq 2}P^{(k-1)}(x,z)P(z,y)=\\sum\_{z\\geq 2}P^{(k-1)}(x,z)P(z,y)
    
    ≤\\displaystyle\\leq
    
    ∑z≥2P⁡(x,z)2k−2⋅P⁡(z,y)\=P(2)​(x,y)2k−2≤P⁡(x,y)2k−1.\\displaystyle\\sum\_{z\\geq 2}\\frac{P(x,z)}{2^{k-2}}\\cdot P(z,y)=\\frac{P^{(2)}(x,y)}{2^{k-2}}\\leq\\frac{P(x,y)}{2^{k-1}}.
    

As P⁡(x,y)≤1P(x,y)\\leq 1, after 1−log2⁡F1-\\log\_{2}F rounds, the transition probability into any state y≥2y\\geq 2 is negligible, starting with any state x≥2x\\geq 2. Although there are many such states yy, it is easy to see that

limy→+∞P⁡(x,y)P⁡(x,y+1)\=limy→+∞(1−h¯y)x−(1−h¯y−1)x(1−h¯y+1)x−(1−h¯y)x\=limy→+∞h¯y−1−h¯yh¯y−h¯y+1\=1h¯\=11−h.\\lim\_{y\\rightarrow+\\infty}\\frac{P(x,y)}{P(x,y+1)}=\\lim\_{y\\rightarrow+\\infty}\\frac{(1-\\bar{h}^{y})^{x}-(1-\\bar{h}^{y-1})^{x}}{(1-\\bar{h}^{y+1})^{x}-(1-\\bar{h}^{y})^{x}}=\\lim\_{y\\rightarrow+\\infty}\\frac{\\bar{h}^{y-1}-\\bar{h}^{y}}{\\bar{h}^{y}-\\bar{h}^{y+1}}=\\frac{1}{\\bar{h}}=\\frac{1}{1-h}.

Therefore each row xx of the transition matrix PP decreases as a geometric sequence with rate 11−h\>2\\frac{1}{1-h}>2 when yy is large enough, and the same holds for P(k)P^{(k)}. Accordingly, when kk is large enough but still on the order of log1/2⁡F\\log\_{1/2}F, ∑y≥2P(k)​(x,y)<F\\sum\_{y\\geq 2}P^{(k)}(x,y)<F for any x≥2x\\geq 2. That is, with overwhelming probability the Adversary loses the game and fails to predict Qr−1Q^{r-1} at round r−kr-k. For h∈(2/3,1\]h\\in(2/3,1\], a more complex analysis shows that there exists a constant CC slightly larger than 1/21/2, such that it suffices to take k\=O⁡(logC⁡F)k=O(\\log\_{C}F). Thus Lemma [5.6](#S5.Thmtheorem6 "Lemma 5.6. ‣ 5.9 Security of the Seed 𝑸^𝒓 and Probability of An Honest Leader ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") holds. ■\\blacksquare

Lemma [5.4](#S5.Thmtheorem4 "Lemma 5.4. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"). (restated) Given Properties 1–3 for each round before rr, ph\=h2​(1+h−h2)p\_{h}=h^{2}(1+h-h^{2}) for LrL^{r}, and the leader ℓr\\ell^{r} is honest with probability at least php\_{h}.

###### Proof.

Following Lemma [5.6](#S5.Thmtheorem6 "Lemma 5.6. ‣ 5.9 Security of the Seed 𝑸^𝒓 and Probability of An Honest Leader ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), the Adversary cannot predict Qr−1Q^{r-1} back at round r−kr-k except with negligible probability. Note that this does not mean the probability of an honest leader is hh for each round. Indeed, given Qr−1Q^{r-1}, depending on how many malicious users are at the beginning of the random permutation of P​Kr−kPK^{r-k}, the Adversary may have more than one options for QrQ^{r} and thus can increase the probability of a malicious leader in round r+1r+1 —again we are giving him some unrealistic advantages as in Lemma [5.6](#S5.Thmtheorem6 "Lemma 5.6. ‣ 5.9 Security of the Seed 𝑸^𝒓 and Probability of An Honest Leader ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND"), so as to simplify the analysis.

However, for each Qr−1Q^{r-1} that was not queried to HH by the Adversary back at round r−kr-k, for any x≥1x\\geq 1, with probability (1−h)x−1​h(1-h)^{x-1}h the first honest user occurs at position xx in the resulting random permutation of P​Kr−kPK^{r-k}. When x\=1x=1, the probability of an honest leader in round r+1r+1 is indeed hh; while when x\=2x=2, the Adversary has two options for QrQ^{r} and the resulting probability is h2h^{2}. Only by considering these two cases, we have that the probability of an honest leader in round r+1r+1 is at least h⋅h+(1−h)​h⋅h2\=h2​(1+h−h2)h\\cdot h+(1-h)h\\cdot h^{2}=h^{2}(1+h-h^{2}) as desired.

Note that the above probability only considers the randomness in the protocol from round r−kr-k to round rr. When all the randomness from round 0 to round rr is taken into consideration, Qr−1Q^{r-1} is even less predictable to the Adversary and the probability of an honest leader in round r+1r+1 is at least h2​(1+h−h2)h^{2}(1+h-h^{2}). Replacing r+1r+1 with rr and shifts everything back by one round, the leader ℓr\\ell^{r} is honest with probability at least h2​(1+h−h2)h^{2}(1+h-h^{2}), as desired.

Similarly, in each Coin-Genuinely-Flipped step ss, the “leader” of that step —that is the verifier in S​Vr,sSV^{r,s} whose credential has the smallest hash value, is honest with probability at least h2​(1+h−h2)h^{2}(1+h-h^{2}). Thus ph\=h2​(1+h−h2)p\_{h}=h^{2}(1+h-h^{2}) for LrL^{r} and Lemma [5.4](#S5.Thmtheorem4 "Lemma 5.4. ‣ Proof of Theorem . ‣ Remarks. ‣ 5.6 Main Theorem ‣ 5 \"Algorand\"^′_𝟏 ‣ ALGORAND") holds. ■\\blacksquare

## 6 Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}

In this section, we construct a version of Algorand′\\text{{Algorand}}\\,^{\\prime} working under the following assumption.

Honest Majority of Users Assumption:

More than 2/3 of the users in each P​KrPK^{r} are honest.

In Section [8](#S8 "8 Protocol \"Algorand\"^′ with Honest Majority of Money ‣ ALGORAND"), we show how to replace the above assumption with the desired Honest Majority of Money assumption.

### 6.1 Additional Notations and Parameters for Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}

##### Notations

-   ∙\\bullet
    
    μ∈ℤ+\\mu\\in\\mathbb{Z}^{+}: a pragmatic upper-bound to the number of steps that, with overwhelming probability, will actually taken in one round. (As we shall see, parameter μ\\mu controls how many ephemeral keys a user prepares in advance for each round.)
    
-   ∙\\bullet
    
    LrL^{r}: a random variable representing the number of Bernoulli trials needed to see a 1, when each trial is 1 with probability ph2\\frac{p\_{h}}{2}. LrL^{r} will be used to upper-bound the time needed to generate block BrB^{r}.
    
-   ∙\\bullet
    
    tHt\_{H}: a lower-bound for the number of honest verifiers in a step s\>1s>1 of round rr, such that with overwhelming probability (given nn and pp), there are \>tH\>t\_{H} honest verifiers in S​Vr,sSV^{r,s}.
    

##### Parameters

-   ∙\\bullet
    
    Relationships among various parameters.
    
    -   —
        
        For each step s\>1s>1 of round rr, nn is chosen so that, with overwhelming probability,
        
        |H​S​Vr,s|\>tH|HSV^{r,s}|>t\_{H}  and  |H​S​Vr,s|+2​|M​S​Vr,s|<2​tH|HSV^{r,s}|+2|MSV^{r,s}|<2t\_{H}.
        
        Note that the two inequalities above together imply |H​S​Vr,s|\>2​|M​S​Vr,s||HSV^{r,s}|>2|MSV^{r,s}|: that is, there is a 2/32/3 honest majority among selected verifiers.
        
        The closer to 1 the value of hh is, the smaller nn needs to be. In particular, we use (variants of) Chernoff bounds to ensure the desired conditions hold with overwhelming probability.
        
    
-   ∙\\bullet
    
    Example choices of important parameters.
    
    -   —
        
        F\=10−18F=10^{-18}.
        
    -   —
        
        n≈4000n\\approx 4000, tH≈0.69​nt\_{H}\\approx 0.69n, k\=70k=70.
        
    

### 6.2 Implementing Ephemeral Keys in Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2}

Recall that a verifier i∈S​Vr,si\\in SV^{r,s} digitally signs his message mir,sm\_{i}^{r,s} of step ss in round rr, relative to an ephemeral public key p​kir,spk\_{i}^{r,s}, using an ephemeral secrete key s​kir,ssk^{r,s}\_{i} that he promptly destroys after using. When the number of possible steps that a round may take is capped by a given integer μ\\mu, we have already seen how to practically handle ephemeral keys. For example, as we have explained in Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1} (where μ\=m+3\\mu=m+3), to handle all his possible ephemeral keys, from a round r′r^{\\prime} to a round r′+106r^{\\prime}+10^{6}, ii generates a pair (P​M​K,S​M​K)(PMK,SMK), where P​M​KPMK public master key of an identity based signature scheme, and S​M​KSMK its corresponding secret master key. User ii publicizes P​M​KPMK and uses S​M​KSMK to generate the secret key of each possible ephemeral public key (and destroys S​M​KSMK after having done so). The set of ii’s ephemeral public keys for the relevant rounds is S\={i}×{r′,…,r′+106}×{1,…,μ}S=\\{i\\}\\times\\{r^{\\prime},\\ldots,r^{\\prime}+10^{6}\\}\\times\\{1,\\ldots,\\mu\\}. (As discussed, as the round r′+106r^{\\prime}+10^{6} approaches, ii “refreshes” his pair (P​M​K,S​M​K)(PMK,SMK).)

In practice, if μ\\mu is large enough, a round of Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2} will not take more than μ\\mu steps. In principle, however, there is the remote possibility that, for some round rr the number of steps actually taken will exceed μ\\mu. When this happens, ii would be unable to sign his message mir,sm\_{i}^{r,s} for any step s\>μs>\\mu, because he has prepared in advance only μ\\mu secret keys for round rr. Moreover, he could not prepare and publicize a new stash of ephemeral keys, as discussed before. In fact, to do so, he would need to insert a new public master key P​M​K′PMK^{\\prime} in a new block. But, should round rr take more and more steps, no new blocks would be generated.

However, solutions exist. For instance, ii may use the last ephemeral key of round rr, p​kir,μpk\_{i}^{r,\\mu}, as follows. He generates another stash of key-pairs for round rr —e.g., by (1) generating another master key pair (P​M​K¯,S​M​K¯)(\\overline{PMK},\\overline{SMK}); (2) using this pair to generate another, say, 10610^{6} ephemeral keys, s​k¯ir,μ+1,…,s​k¯ir,μ+106\\overline{sk}\_{i}^{r,\\mu+1},\\ldots,\\overline{sk}\_{i}^{r,\\mu+10^{6}}, corresponding to steps μ+1,…,μ+106\\mu+1,...,\\mu+10^{6} of round rr; (3) using s​kir,μsk\_{i}^{r,\\mu} to digitally sign P​M​K¯\\overline{PMK} (and any (r,μ)(r,\\mu)\-message if i∈S​Vr,μi\\in SV^{r,\\mu}), relative to p​kir,μpk\_{i}^{r,\\mu}; and (4) erasing S​M​K¯\\overline{SMK} and s​kir,μsk\_{i}^{r,\\mu}. Should ii become a verifier in a step μ+s\\mu+s with s∈{1,…,106}s\\in\\{1,\\dots,10^{6}\\}, then ii digitally signs his (r,μ+s)(r,\\mu+s)\-message mir,μ+sm^{r,\\mu+s}\_{i} relative to his new key p​k¯ir,μ+s\=(i,r,μ+s)\\overline{pk}\_{i}^{r,\\mu+s}=(i,r,\\mu+s). Of course, to verify this signature of ii, others need to be certain that this public key corresponds to ii’s new public master key P​M​K¯\\overline{PMK}. Thus, in addition to this signature, ii transmits his digital signature of P​M​K¯\\overline{PMK} relative to p​kir,μpk\_{i}^{r,\\mu}.

Of course, this approach can be repeated, as many times as necessary, should round rr continue for more and more steps! The last ephemeral secret key is used to authenticate a new master public key, and thus another stash of ephemeral keys for round rr. And so on.

### 6.3 The Actual Protocol Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}

Recall again that, in each step ss of a round rr, a verifier i∈S​Vr,si\\in SV^{r,s} uses his long-term public-secret key pair to produce his credential, σir,s≜S​I​Gi​(r,s,Qr−1)\\sigma\_{i}^{r,s}\\triangleq SIG\_{i}(r,s,Q^{r-1}), as well as S​I​Gi​(Qr−1)SIG\_{i}\\left(Q^{r-1}\\right) in case s\=1s=1. Verifier ii uses his ephemeral key pair, (OPENp​kir,s,s​kir,s)pk\_{i}^{r,s},sk\_{i}^{r,s}), to sign any other message mm that may be required. For simplicity, we write e​s​i​gi​(m)esig\_{i}(m), rather than s​i​gp​kir,s​(m)sig\_{pk^{r,s}\_{i}}(m), to denote ii’s proper ephemeral signature of mm in this step, and write E​S​I​Gi​(m)ESIG\_{i}(m) instead of S​I​Gp​kir,s​(m)≜(i,m,e​s​i​gi​(m))SIG\_{pk\_{i}^{r,s}}(m)\\triangleq(i,m,esig\_{i}(m)).

Step 1: Block Proposal Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step 1 of round rr as soon as he has C​E​R​Tr−1CERT^{r-1}, which allows ii to unambiguously compute H⁡(Br−1)H(B^{r-1}) and Qr−1Q^{r-1}. • User ii uses Qr−1Q^{r-1} to check whether i∈S​Vr,1i\\in SV^{r,1} or not. If i∉S​Vr,1i\\notin SV^{r,1}, he does nothing for Step 1. • If i∈S​Vr,1i\\in SV^{r,1}, that is, if ii is a potential leader, then he does the following. (a) If ii has seen B0,…,Br−1B^{0},\\ldots,B^{r-1} himself (any Bj\=BϵjB^{j}=B^{j}\_{\\epsilon} can be easily derived from its hash value in C​E​R​TjCERT^{j} and is thus assumed “seen”), then he collects the round-rr payments that have been propagated to him so far and computes a maximal payset P​A​YirPAY^{r}\_{i} from them. (b) If ii hasn’t seen all B0,…,Br−1B^{0},\\ldots,B^{r-1} yet, then he sets P​A​Yir\=∅PAY^{r}\_{i}=\\emptyset. (c) Next, ii computes his “candidate block” Bir\=(r,P​A​Yir,S​I​Gi​(Qr−1),H⁡(Br−1))B^{r}\_{i}=(r,PAY^{r}\_{i},SIG\_{i}(Q^{r-1}),H(B^{r-1})). (c) Finally, ii computes the message mir,1\=(Bir,e​s​i​gi​(H⁡(Bir)),σir,1)m^{r,1}\_{i}=(B^{r}\_{i},esig\_{i}(H(B^{r}\_{i})),\\sigma^{r,1}\_{i}), destroys his ephemeral secret key s​kir,1sk^{r,1}\_{i}, and then propagates two messages, mir,1m^{r,1}\_{i} and (S​I​Gi​(Qr−1),σir,1)(SIG\_{i}(Q^{r-1}),\\sigma^{r,1}\_{i}), separately but simultaneously.3434 34 When ii is the leader, S​I​Gi​(Qr−1)SIG\_{i}(Q^{r-1}) allows others to compute Qr\=H⁡(S​I​Gi​(Qr−1),r)Q^{r}=H(SIG\_{i}(Q^{r-1}),r).

Selective Propagation To shorten the global execution of Step 1 and the whole round, it is important that the (r,1)(r,1)\-messages are selectively propagated. That is, for every user jj in the system, • For the first (r,1)(r,1)\-message that he ever receives and successfully verifies,3535 35 That is, all the signatures are correct and, if it is of the form mir,1m^{r,1}\_{i}, both the block and its hash are valid —although jj does not check whether the included payset is maximal for ii or not. whether it contains a block or is just a credential and a signature of Qr−1Q^{r-1}, player jj propagates it as usual. • For all the other (r,1)(r,1)\-messages that player jj receives and successfully verifies, he propagates it only if the hash value of the credential it contains is the smallest among the hash values of the credentials contained in all (r,1)(r,1)\-messages he has received and successfully verified so far. • However, if jj receives two different messages of the form mir,1m^{r,1}\_{i} from the same player ii,3636 36 Which means ii is malicious. he discards the second one no matter what the hash value of ii’s credential is. Note that, under selective propagation it is useful that each potential leader ii propagates his credential σir,1\\sigma^{r,1}\_{i} separately from mir,1m^{r,1}\_{i}:3737 37 We thank Georgios Vlachos for suggesting this. those small messages travel faster than blocks, ensure timely propagation of the mir,1m^{r,1}\_{i}’s where the contained credentials have small hash values, while make those with large hash values disappear quickly.

Step 2: The First Step of the Graded Consensus Protocol G​CGC Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step 2 of round rr as soon as he has C​E​R​Tr−1CERT^{r-1}. • User ii waits a maximum amount of time t2≜λ+Λt\_{2}\\triangleq\\lambda+\\Lambda. While waiting, ii acts as follows. 1. After waiting for time 2​λ2\\lambda, he finds the user ℓ\\ell such that H⁡(σℓr,1)≤H⁡(σjr,1)H(\\sigma^{r,1}\_{\\ell})\\leq H(\\sigma^{r,1}\_{j}) for all credentials σjr,1\\sigma^{r,1}\_{j} that are part of the successfully verified (r,1)(r,1)\-messages he has received so far.3838 38 Essentially, user ii privately decides that the leader of round rr is user ℓ\\ell. 2. If he has received a block Br−1B^{r-1}, which matches the hash value H⁡(Br−1)H(B^{r-1}) contained in C​E​R​Tr−1CERT^{r-1},3939 39 Of course, if C​E​R​Tr−1CERT^{r-1} indicates that Br−1\=Bϵr−1B^{r-1}=B^{r-1}\_{\\epsilon}, then ii has already “received” Br−1B^{r-1} the moment he has C​E​R​Tr−1CERT^{r-1}. and if he has received from ℓ\\ell a valid message mℓr,1\=(Bℓr,e​s​i​gℓ​(H⁡(Bℓr)),σℓr,1)m^{r,1}\_{\\ell}=(B^{r}\_{\\ell},esig\_{\\ell}(H(B^{r}\_{\\ell})),\\sigma^{r,1}\_{\\ell}),4040 40 Again, player ℓ\\ell’s signatures and the hashes are all successfully verified, and P​A​YℓrPAY^{r}\_{\\ell} in BℓrB^{r}\_{\\ell} is a valid payset for round rr —although ii does not check whether P​A​YℓrPAY^{r}\_{\\ell} is maximal for ℓ\\ell or not. If BℓrB^{r}\_{\\ell} contains an empty payset, then there is actually no need for ii to see Br−1B^{r-1} before verifying whether BℓrB^{r}\_{\\ell} is valid or not. then ii stops waiting and sets vi′≜(H⁡(Bℓr),ℓ)v^{\\prime}\_{i}\\triangleq(H(B^{r}\_{\\ell}),\\ell). 3. Otherwise, when time t2t\_{2} runs out, ii sets v′i≜⊥v^{\\prime}\_{i}\\triangleq\\bot. 4. When the value of vi′v^{\\prime}\_{i} has been set, ii computes Qr−1Q^{r-1} from C​E​R​Tr−1CERT^{r-1} and checks whether i∈S​Vr,2i\\in SV^{r,2} or not. 5. If i∈S​Vr,2i\\in SV^{r,2}, ii computes the message mir,2≜(E​S​I​Gi​(vi′),σir,2)m^{r,2}\_{i}\\triangleq(ESIG\_{i}(v^{\\prime}\_{i}),\\sigma^{r,2}\_{i}),4141 41 The message mir,2m^{r,2}\_{i} signals that player ii considers the first component of vi′v^{\\prime}\_{i} to be the hash of the next block, or considers the next block to be empty. destroys his ephemeral secret key s​kir,2sk^{r,2}\_{i}, and then propagates mir,2m^{r,2}\_{i}. Otherwise, ii stops without propagating anything.

Step 3: The Second Step of G​CGC Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step 3 of round rr as soon as he has C​E​R​Tr−1CERT^{r-1}. • User ii waits a maximum amount of time t3≜t2+2​λ\=3​λ+Λt\_{3}\\triangleq t\_{2}+2\\lambda=3\\lambda+\\Lambda. While waiting, ii acts as follows. 1. If there exists a value vv such that he has received at least tHt\_{H} valid messages mjr,2m^{r,2}\_{j} of the form (E​S​I​Gj​(v),σjr,2)(ESIG\_{j}(v),\\sigma^{r,2}\_{j}), without any contradiction,4242 42 That is, he has not received two valid messages containing E​S​I​Gj​(v)ESIG\_{j}(v) and a different E​S​I​Gj​(v^)ESIG\_{j}(\\hat{v}) respectively, from a player jj. Here and from here on, except in the Ending Conditions defined later, whenever an honest player wants messages of a given form, messages contradicting each other are never counted or considered valid. then he stops waiting and sets v′\=vv^{\\prime}=v. 2. Otherwise, when time t3t\_{3} runs out, he sets v′\=⊥v^{\\prime}=\\bot. 3. When the value of v′v^{\\prime} has been set, ii computes Qr−1Q^{r-1} from C​E​R​Tr−1CERT^{r-1} and checks whether i∈S​Vr,3i\\in SV^{r,3} or not. 4. If i∈S​Vr,3i\\in SV^{r,3}, then ii computes the message mir,3≜(E​S​I​Gi​(v′),σir,3)m\_{i}^{r,3}\\triangleq(ESIG\_{i}(v^{\\prime}),\\sigma^{r,3}\_{i}), destroys his ephemeral secret key s​kir,3sk^{r,3}\_{i}, and then propagates mir,3m\_{i}^{r,3}. Otherwise, ii stops without propagating anything.

Step 4: Output of G​CGC and The First Step of B​B​A⋆BBA^{\\star} Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step 4 of round rr as soon as he finishes his own Step 3. • User ii waits a maximum amount of time 2​λ2\\lambda.4343 43 Thus, the maximum total amount of time since ii starts his Step 1 of round rr could be t4≜t3+2​λ\=5​λ+Λt\_{4}\\triangleq t\_{3}+2\\lambda=5\\lambda+\\Lambda. While waiting, ii acts as follows. 1. He computes viv\_{i} and gig\_{i}, the output of GC, as follows. (a) If there exists a value v′≠⊥v^{\\prime}\\neq\\bot such that he has received at least tHt\_{H} valid messages mjr,3\=(E​S​I​Gj​(v′),σjr,3)m\_{j}^{r,3}=(ESIG\_{j}(v^{\\prime}),\\sigma\_{j}^{r,3}), then he stops waiting and sets vi≜v′v\_{i}\\triangleq v^{\\prime} and gi≜2g\_{i}\\triangleq 2. (b) If he has received at least tHt\_{H} valid messages mjr,3\=(E​S​I​Gj​(⊥),σjr,3)m\_{j}^{r,3}=(ESIG\_{j}(\\bot),\\sigma\_{j}^{r,3}), then he stops waiting and sets vi≜⊥v\_{i}\\triangleq\\bot and gi≜0g\_{i}\\triangleq 0.4444 44 Whether Step (b) is in the protocol or not does not affect its correctness. However, the presence of Step (b) allows Step 4 to end in less than 2​λ2\\lambda time if sufficiently many Step-3 verifiers have “signed ⊥\\bot.” (c) Otherwise, when time 2​λ2\\lambda runs out, if there exists a value v′≠⊥v^{\\prime}\\neq\\bot such that he has received at least ⌈tH2⌉\\lceil\\frac{t\_{H}}{2}\\rceil valid messages mjr,j\=(E​S​I​Gj​(v′),σjr,3)m^{r,j}\_{j}=(ESIG\_{j}(v^{\\prime}),\\sigma\_{j}^{r,3}), then he sets vi≜v′v\_{i}\\triangleq v^{\\prime} and gi≜1g\_{i}\\triangleq 1.4545 45 It can be proved that the v′v^{\\prime} in this case, if exists, must be unique. (d) Else, when time 2​λ2\\lambda runs out, he sets vi≜⊥v\_{i}\\triangleq\\bot and gi≜0g\_{i}\\triangleq 0. 2. When the values viv\_{i} and gig\_{i} have been set, ii computes bib\_{i}, the input of B​B​A⋆BBA^{\\star}, as follows: bi≜0b\_{i}\\triangleq 0 if gi\=2g\_{i}=2, and bi≜1b\_{i}\\triangleq 1 otherwise. 3. ii computes Qr−1Q^{r-1} from C​E​R​Tr−1CERT^{r-1} and checks whether i∈S​Vr,4i\\in SV^{r,4} or not. 4. If i∈S​Vr,4i\\in SV^{r,4}, he computes the message mir,4≜(E​S​I​Gi​(bi),E​S​I​Gi​(vi),σir,4)m^{r,4}\_{i}\\triangleq(ESIG\_{i}(b\_{i}),ESIG\_{i}(v\_{i}),\\sigma^{r,4}\_{i}), destroys his ephemeral secret key s​kir,4sk^{r,4}\_{i}, and propagates mir,4m^{r,4}\_{i}. Otherwise, ii stops without propagating anything.

Step ss, 5≤s≤m+25\\leq s\\leq m+2, s−2≡0mod3s-2\\equiv 0\\mod 3: A Coin-Fixed-To-0 Step of B​B​A⋆BBA^{\\star} Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step ss of round rr as soon as he finishes his own Step s−1s-1. ∙\\bullet User ii waits a maximum amount of time 2​λ2\\lambda.4646 46 Thus, the maximum total amount of time since ii starts his Step 1 of round rr could be ts≜ts−1+2​λ\=(2​s−3)​λ+Λt\_{s}\\triangleq t\_{s-1}+2\\lambda=(2s-3)\\lambda+\\Lambda. While waiting, ii acts as follows. – Ending Condition 0: If at any point there exists a string v≠⊥v\\neq\\bot and a step s′s^{\\prime} such that (a) 5≤s′≤s5\\leq s^{\\prime}\\leq s, s′−2≡0mod3s^{\\prime}-2\\equiv 0\\mod 3 —that is, Step s′s^{\\prime} is a Coin-Fixed-To-0 step, (b) ii has received at least tHt\_{H} valid messages mjr,s′−1\=(E​S​I​Gj​(0)CLOSE,m^{r,s^{\\prime}-1}\_{j}=(ESIG\_{j}(0), OPENE​S​I​Gj​(v),σjr,s′−1)ESIG\_{j}(v),\\sigma^{r,s^{\\prime}-1}\_{j}),4747 47 Such a message from player jj is counted even if player ii has also received a message from jj signing for 1. Similar things for Ending Condition 1. As shown in the analysis, this is to ensure that all honest users know C​E​R​TrCERT^{r} within time λ\\lambda from each other. and (c) ii has received a valid message (S​I​Gj​(Qr−1),σjr,1)(SIG\_{j}(Q^{r-1}),\\sigma^{r,1}\_{j}) with jj being the second component of vv, then, ii stops waiting and ends his own execution of Step ss (and in fact of round rr) right away without propagating anything as a (r,s)(r,s)\-verifier; sets H⁡(Br)H(B^{r}) to be the first component of vv; and sets his own C​E​R​TrCERT^{r} to be the set of messages mjr,s′−1m^{r,s^{\\prime}-1}\_{j} of step (b) together with (S​I​Gj​(Qr−1),σjr,1)(SIG\_{j}(Q^{r-1}),\\sigma^{r,1}\_{j}).4848 48 User ii now knows H⁡(Br)H(B^{r}) and his own round rr finishes. He just needs to wait until the actually block BrB^{r} is propagated to him, which may take some additional time. He still helps propagating messages as a generic user, but does not initiate any propagation as a (r,s)(r,s)\-verifier. In particular, he has helped propagating all messages in his C​E​R​TrCERT^{r}, which is enough for our protocol. Note that he should also set bi≜0b\_{i}\\triangleq 0 for the binary BA protocol, but bib\_{i} is not needed in this case anyway. Similar things for all future instructions. – Ending Condition 1: If at any point there exists a step s′s^{\\prime} such that (a’) 6≤s′≤s6\\leq s^{\\prime}\\leq s, s′−2≡1mod3s^{\\prime}-2\\equiv 1\\mod 3 —that is, Step s′s^{\\prime} is a Coin-Fixed-To-1 step, and (b’) ii has received at least tHt\_{H} valid messages mjr,s′−1\=(E​S​I​Gj​(1),E​S​I​Gj​(vj)CLOSE,m^{r,s^{\\prime}-1}\_{j}=(ESIG\_{j}(1),ESIG\_{j}(v\_{j}), OPENσjr,s′−1)\\sigma^{r,s^{\\prime}-1}\_{j}),4949 49 In this case, it does not matter what the vjv\_{j}’s are. then, ii stops waiting and ends his own execution of Step ss (and in fact of round rr) right away without propagating anything as a (r,s)(r,s)\-verifier; sets Br\=BϵrB^{r}=B^{r}\_{\\epsilon}; and sets his own C​E​R​TrCERT^{r} to be the set of messages mjr,s′−1m^{r,s^{\\prime}-1}\_{j} of sub-step (b’). – If at any point he has received at least tHt\_{H} valid mjr,s−1m^{r,s-1}\_{j}’s of the form (E​S​I​Gj​(1),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(1),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he stops waiting and sets bi≜1b\_{i}\\triangleq 1. – If at any point he has received at least tHt\_{H} valid mjr,s−1m^{r,s-1}\_{j}’s of the form (E​S​I​Gj​(0),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(0),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), but they do not agree on the same vv, then he stops waiting and sets bi≜0b\_{i}\\triangleq 0. – Otherwise, when time 2​λ2\\lambda runs out, ii sets bi≜0b\_{i}\\triangleq 0. – When the value bib\_{i} has been set, ii computes Qr−1Q^{r-1} from C​E​R​Tr−1CERT^{r-1} and checks whether i∈S​Vr,si\\in SV^{r,s}. – If i∈S​Vr,si\\in SV^{r,s}, ii computes the message mir,s≜(E​S​I​Gi​(bi),E​S​I​Gi​(vi),σir,s)m^{r,s}\_{i}\\triangleq(ESIG\_{i}(b\_{i}),ESIG\_{i}(v\_{i}),\\sigma^{r,s}\_{i}) with viv\_{i} being the value he has computed in Step 4, destroys his ephemeral secret key s​kir,ssk^{r,s}\_{i}, and then propagates mir,sm^{r,s}\_{i}. Otherwise, ii stops without propagating anything.

Step ss, 6≤s≤m+26\\leq s\\leq m+2, s−2≡1mod3s-2\\equiv 1\\mod 3: A Coin-Fixed-To-1 Step of B​B​A⋆BBA^{\\star} Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step ss of round rr as soon as he finishes his own Step s−1s-1. • User ii waits a maximum amount of time 2​λ2\\lambda. While waiting, ii acts as follows. – Ending Condition 0: The same instructions as in a Coin-Fixed-To-0 step. – Ending Condition 1: The same instructions as in a Coin-Fixed-To-0 step. – If at any point he has received at least tHt\_{H} valid mjr,s−1m^{r,s-1}\_{j}’s of the form (E​S​I​Gj​(0),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(0),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he stops waiting and sets bi≜0b\_{i}\\triangleq 0.5050 50 Note that receiving tHt\_{H} valid (r,s−1)(r,s-1)\-messages signing for 1 would mean Ending Condition 1. – Otherwise, when time 2​λ2\\lambda runs out, ii sets bi≜1b\_{i}\\triangleq 1. – When the value bib\_{i} has been set, ii computes Qr−1Q^{r-1} from C​E​R​Tr−1CERT^{r-1} and checks whether i∈S​Vr,si\\in SV^{r,s}. – If i∈S​Vr,si\\in SV^{r,s}, ii computes the message mir,s≜(E​S​I​Gi​(bi),E​S​I​Gi​(vi),σir,s)m^{r,s}\_{i}\\triangleq(ESIG\_{i}(b\_{i}),ESIG\_{i}(v\_{i}),\\sigma^{r,s}\_{i}) with viv\_{i} being the value he has computed in Step 4, destroys his ephemeral secret key s​kir,ssk^{r,s}\_{i}, and then propagates mir,sm^{r,s}\_{i}. Otherwise, ii stops without propagating anything.

Step ss, 7≤s≤m+27\\leq s\\leq m+2, s−2≡2mod3s-2\\equiv 2\\mod 3: A Coin-Genuinely-Flipped Step of B​B​A⋆BBA^{\\star} Instructions for every user i∈P​Kr−ki\\in PK^{r-k}: User ii starts his own Step ss of round rr as soon as he finishes his own step s−1s-1. • User ii waits a maximum amount of time 2​λ2\\lambda. While waiting, ii acts as follows. – Ending Condition 0: The same instructions as in a Coin-Fixed-To-0 step. – Ending Condition 1: The same instructions as in a Coin-Fixed-To-0 step. – If at any point he has received at least tHt\_{H} valid mjr,s−1m^{r,s-1}\_{j}’s of the form (E​S​I​Gj​(0),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(0),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he stops waiting and sets bi≜0b\_{i}\\triangleq 0. – If at any point he has received at least tHt\_{H} valid mjr,s−1m^{r,s-1}\_{j}’s of the form (E​S​I​Gj​(1),E​S​I​Gj​(vj),σjr,s−1)(ESIG\_{j}(1),ESIG\_{j}(v\_{j}),\\sigma^{r,s-1}\_{j}), then he stops waiting and sets bi≜1b\_{i}\\triangleq 1. – Otherwise, when time 2​λ2\\lambda runs out, letting S​Vir,s−1SV^{r,s-1}\_{i} be the set of (r,s−1)(r,s-1)\-verifiers from whom he has received a valid message mjr,s−1m^{r,s-1}\_{j}, ii sets bi≜𝚕𝚜𝚋⁡(minj∈SVir,s−1⁡H⁡(σjr,s−1))b\_{i}\\triangleq\\lsb(\\min\_{j\\in SV^{r,s-1}\_{i}}H(\\sigma^{r,s-1}\_{j})). – When the value bib\_{i} has been set, ii computes Qr−1Q^{r-1} from C​E​R​Tr−1CERT^{r-1} and checks whether i∈S​Vr,si\\in SV^{r,s}. – If i∈S​Vr,si\\in SV^{r,s}, ii computes the message mir,s≜(E​S​I​Gi​(bi),E​S​I​Gi​(vi),σir,s)m^{r,s}\_{i}\\triangleq(ESIG\_{i}(b\_{i}),ESIG\_{i}(v\_{i}),\\sigma^{r,s}\_{i}) with viv\_{i} being the value he has computed in Step 4, destroys his ephemeral secret key s​kir,ssk^{r,s}\_{i}, and then propagates mir,sm^{r,s}\_{i}. Otherwise, ii stops without propagating anything.

##### Remark.

In principle, as considered in subsection [6.2](#S6.SS2 "6.2 Implementing Ephemeral Keys in \"Algorand\"^′_2 ‣ 6 \"Algorand\"^′_𝟐 ‣ ALGORAND"), the protocol may take arbitrarily many steps in some round. Should this happens, as discussed, a user i∈S​Vr,si\\in SV^{r,s} with s\>μs>\\mu has exhausted his stash of pre-generated ephemeral keys and has to authenticate his (r,s)(r,s)\-message mir,sm^{r,s}\_{i} by a “cascade” of ephemeral keys. Thus ii’s message becomes a bit longer and transmitting these longer messages will take a bit more time. Accordingly, after so many steps of a given round, the value of the parameter λ\\lambda will automatically increase slightly. (But it reverts to the original λ\\lambda once a new block is produced and a new round starts.)

Reconstruction of the Round-rr Block by Non-Verifiers Instructions for every user ii in the system: User ii starts his own round rr as soon as he has C​E​R​Tr−1CERT^{r-1}. • ii follows the instructions of each step of the protocol, participates the propagation of all messages, but does not initiate any propagation in a step if he is not a verifier in it. • ii ends his own round rr by entering either Ending Condition 0 or Ending Condition 1 in some step, with the corresponding C​E​R​TrCERT^{r}. • From there on, he starts his round r+1r+1 while waiting to receive the actual block BrB^{r} (unless he has already received it), whose hash H⁡(Br)H(B^{r}) has been pinned down by C​E​R​TrCERT^{r}. Again, if C​E​R​TrCERT^{r} indicates that Br\=BϵrB^{r}=B^{r}\_{\\epsilon}, the ii knows BrB^{r} the moment he has C​E​R​TrCERT^{r}.

### 6.4 Analysis of Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}

The analysis of Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2} is easily derived from that of Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1}. Essentially, in Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2}, with overwhelming probability, (a) all honest users agree on the same block BrB^{r}; the leader of a new block is honest with probability at least ph\=h2​(1+h−h2)p\_{h}=h^{2}(1+h-h^{2}).

## 7 Handling Offline Honest users

As we said, a honest user follows all his prescribed instructions, which include that of being online and running the protocol. This is not a major burden in Algorand, since the computation and bandwidth required from a honest user are quite modest. Yet, let us point out that Algorand can be easily modified so as to work in two models, in which honest users are allowed to be offline in great numbers.

Before discussing these two models, let us point out that, if the percentage of honest players were 95%, Algorand could still be run setting all parameters assuming instead that h\=80%h=80\\%. Accordingly, Algorand would continue to work properly even if at most half of the honest players chose to go offline (indeed, a major case of“absenteeism”). In fact, at any point in time, at least 80% of the players online would be honest.

##### From Continual Participation to Lazy Honesty

As we saw, Algorand1′\\text{{Algorand}}\\,^{\\prime}\_{1} and Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2} choose the look-back parameter kk. Let us now show that choosing kk properly large enables one to remove the Continual Participation requirement. This requirement ensures a crucial property: namely, that the underlying BA protocol B​B​A⋆BBA^{\\star} has a proper honest majority. Let us now explain how lazy honesty provides an alternative and attractive way to satisfy this property.

Recall that a user ii is lazy-but-honest if (1) he follows all his prescribed instructions, when he is asked to participate to the protocol, and (2) he is asked to participate to the protocol only very rarely —e.g., once a week— with suitable advance notice, and potentially receiving significant rewards when he participates.

To allow Algorand to work with such players, it just suffices to “choose the verifiers of the current round among the users already in the system in a much earlier round.” Indeed, recall that the verifiers for a round rr are chosen from users in round r−kr-k, and the selections are made based on the quantity Qr−1Q^{r-1}. Note that a week consists of roughly 10,000 minutes, and assume that a round takes roughly (e.g., on average) 5 minutes, so a week has roughly 2,000 rounds. Assume that, at some point of time, a user ii wishes to plan his time and know whether he is going to be a verifier in the coming week. The protocol now chooses the verifiers for a round rr from users in round r−k−2,000r-k-2,000, and the selections are based on Qr−2,001Q^{r-2,001}. At round rr, player ii already knows the values Qr−2,000,…,Qr−1Q^{r-2,000},\\ldots,Q^{r-1}, since they are actually part of the blockchain. Then, for each MM between 1 and 2,000, ii is a verifier in a step ss of round r+Mr+M if and only if

.H(SIGi(r+M,s,Qr+M−2,001))≤p..H\\left(SIG\_{i}\\left(r+M,s,Q^{r+M-2,001}\\right)\\right)\\leq p\\kern 5.0pt.

Thus, to check whether he is going to be called to act as a verifier in the next 2,000 rounds, ii must compute σiM,s\=S​I​Gi​(r+M,s,Qr+M−2,001)\\sigma^{M,s}\_{i}=SIG\_{i}\\left(r+M,s,Q^{r+M-2,001}\\right) for M\=1M=1 to 2,0002,000 and for each step ss, and check whether .H(σiM,s)≤p.H(\\sigma^{M,s}\_{i})\\leq p for some of them. If computing a digital signature takes a millisecond, then this entire operation will take him about 1 minute of computation. If he is not selected as a verifier in any of these rounds, then he can go off-line with an “honest conscience”. Had he continuously participated, he would have essentially taken 0 steps in the next 2,000 rounds anyway! If, instead, he is selected to be a verifier in one of these rounds, then he readies himself (e.g., by obtaining all the information necessary) to act as an honest verifier at the proper round.

By so acting, a lazy-but-honest potential verifier ii only misses participating to the propagation of messages. But message propagation is typically robust. Moreover, the payers and the payees of recently propagated payments are expected to be online to watch what happens to their payments, and thus they will participate to message propagation, if they are honest.

## 8 Protocol Algorand′\\bm{\\text{{Algorand}}\\,^{\\prime}} with Honest Majority of Money

We now, finally, show how to replace the Honest Majority of Users assumption with the much more meaningful Honest Majority of Money assumption. The basic idea is (in a proof-of-stake flavor) “to select a user i∈P​Kr−ki\\in PK^{r-k} to belong to S​Vr,sSV^{r,s} with a weight (i.e., decision power) proportional to the amount of money owned by ii.’’5151 51 We should say P​Kr−k−2,000PK^{r-k-2,000} so as to replace continual participation. For simplicity, since one may wish to require continual participation anyway, we use P​Kr−kPK^{r-k} as before, so as to carry one less parameter.

By our HMM assumption, we can choose whether that amount should be owned at round r−kr-k or at (the start of) round rr. Assuming that we do not mind continual participation, we opt for the latter choice. (To remove continual participation, we would have opted for the former choice. Better said, for the amount of money owned at round r−k−2,000r-k-2,000.)

There are many ways to implement this idea. The simplest way would be to have each key hold at most 1 unit of money and then select at random nn users ii from P​Kr−kPK^{r-k} such that ai(r)\=1a\_{i}^{(r)}=1.

#### The Next Simplest Implementation

The next simplest implementation may be to demand that each public key owns a maximum amount of money MM, for some fixed MM. The value MM is small enough compared with the total amount of money in the system, such that the probability a key belongs to the verifier set of more than one step in —say— kk rounds is negligible. Then, a key i∈P​Kr−ki\\in PK^{r-k}, owning an amount of money ai(r)a\_{i}^{(r)} in round rr, is chosen to belong to S​Vr,sSV^{r,s} if

.H(SIGi(r,s,Qr−1))≤p⋅ai(r)M..H\\left(SIG\_{i}\\left(r,s,Q^{r-1}\\right)\\right)\\leq p\\cdot\\frac{a\_{i}^{(r)}}{M}\\kern 5.0pt.

And all proceeds as before.

#### A More Complex Implementation

The last implementation “forced a rich participant in the system to own many keys”.

An alternative implementation, described below, generalizes the notion of status and consider each user ii to consist of K+1K+1 copies (i,v)(i,v), each of which is independently selected to be a verifier, and will own his own ephemeral key (p​ki,vr,s,s​ki,vr,s)(pk\_{i,v}^{r,s},sk\_{i,v}^{r,s}) in a step ss of a round rr. The value KK depends on the amount of money ai(r)a\_{i}^{(r)} owned by ii in round rr.

Let us now see how such a system works in greater detail.

##### Number of Copies

Let nn be the targeted expected cardinality of each verifier set, and let ai(r)a\_{i}^{(r)} be the amount of money owned by a user ii at round rr. Let ArA^{r} be the total amount of money owned by the users in P​Kr−kPK^{r-k} at round rr, that is,

Ar\=∑i∈P​Kr−kai(r).A^{r}=\\sum\_{i\\in PK^{r-k}}a\_{i}^{(r)}.

If ii is an user in P​Kr−kPK^{r-k}, then ii’s copies are (i,1),…,(i,K+1)(i,1),\\ldots,(i,K+1), where

K\=⌊n⋅ai(r)Ar⌋.K=\\left\\lfloor\\frac{n\\cdot a\_{i}^{(r)}}{A^{r}}\\right\\rfloor\\kern 5.0pt.

Example. Let n\=1,000n=1,000, Ar\=109A^{r}=10^{9}, and ai(r)\=3.7a\_{i}^{(r)}=3.7 millions. Then,

K\=⌊103⋅(3.7⋅106)109⌋\=⌊3.7⌋\=3.K=\\left\\lfloor\\frac{10^{3}\\cdot(3.7\\cdot 10^{6})}{10^{9}}\\right\\rfloor=\\lfloor 3.7\\rfloor=3\\kern 5.0pt.

##### Verifiers and Credentials

Let ii be a user in P​Kr−kPK^{r-k} with K+1K+1 copies.

For each v\=1,…,Kv=1,\\ldots,K, copy (i,v)(i,v) belongs to S​Vr,sSV^{r,s} automatically. That is, ii’s credential is σi,vr,s≜S​I​Gi​((i,v),r,s,Qr−1)\\sigma^{r,s}\_{i,v}\\triangleq SIG\_{i}((i,v),r,s,Q^{r-1}), but the corresponding condition becomes .H(σi,vr,s)≤1.H(\\sigma^{r,s}\_{i,v})\\leq 1, which is always true.

For copy (i,K+1)(i,K+1), for each Step ss of round rr, ii checks whether

.H(SIGi((i,K+1),r,s,Qr−1))≤ai(r)nAr−K..H\\big(SIG\_{i}\\big(\\,(i,K+1),r,s,Q^{r-1}\\,\\big)\\big)\\leq a\_{i}^{(r)}\\frac{n}{A^{r}}-K\\kern 5.0pt.

If so, copy (i,K+1)(i,K+1) belongs to S​Vr,sSV^{r,s}. To prove it, ii propagates the credential

σi,K+1r,1\=S​I​Gi​((i,K+1),r,s,Qr−1).\\sigma\_{i,K+1}^{r,1}=SIG\_{i}\\big(\\,(i,K+1),r,s,Q^{r-1}\\,\\big).

Example. As in the previous example, let n\=1​Kn=1K, ai(r)\=3.7​Ma\_{i}^{(r)}=3.7M, Ar\=1​BA^{r}=1B, and ii has 4 copies: (i,1),…,(i,4)(i,1),\\ldots,(i,4). Then, the first 3 copies belong to S​Vr,sSV^{r,s} automatically. For the 4th one, conceptually, Algorand′\\text{{Algorand}}\\,^{\\prime} independently rolls a biased coin, whose probability of Heads is 0.7. Copy (i,4)(i,4) is selected if and only if the coin toss is Heads.

(Of course, this biased coin flip is implemented by hashing, signing, and comparing —as we have done all along in this paper— so as to enable ii to prove his result.)

##### Business as Usual

Having explained how verifiers are selected and how their credentials are computed at each step of a round rr, the execution of a round is similar to that already explained.

## 9 Handling Forks

Having reduced the probability of forks to 10−1210^{-12} or 10−1810^{-18}, it is practically unnecessary to handle them in the remote chance that they occur. Algorand, however, can also employ various fork resolution procedures, with or without proof of work.

One possible way of instructing the users to resolve forks is as follows:

-   •
    
    Follow the longest chain if a user sees multiple chains.
    
-   •
    
    If there are more than one longest chains, follow the one with a non-empty block at the end. If all of them have empty blocks at the end, consider their second-last blocks.
    
-   •
    
    If there are more than one longest chains with non-empty blocks at the end, say the chains are of length rr, follow the one whose leader of block rr has the smallest credential. If there are ties, follow the one whose block rr itself has the smallest hash value. If there are still ties, follow the one whose block rr is ordered the first lexicographically.
    

## 10 Handling Network Partitions

As said, we assume the propagation times of messages among all users in the network are upper-bounded by λ\\lambda and Λ\\Lambda. This is not a strong assumption, as today’s Internet is fast and robust, and the actual values of these parameters are quite reasonable. Here, let us point out that Algorand2′\\text{{Algorand}}\\,^{\\prime}\_{2} continues to work even if the Internet occasionally got partitioned into two parts. The case when the Internet is partitioned into more than two parts is similar.

### 10.1 Physical Partitions

First of all, the partition may be caused by physical reasons. For example, a huge earthquake may end up completely breaking down the connection between Europe and America. In this case, the malicious users are also partitioned and there is no communication between the two parts. Thus there will be two Adversaries, one for part 1 and the other for part 2. Each Adversary still tries to break the protocol in its own part.

Assume the partition happens in the middle of round rr. Then each user is still selected as a verifier based on P​Kr−kPK^{r-k}, with the same probability as before. Let H​S​Vir,sHSV\_{i}^{r,s} and M​S​Vir,sMSV\_{i}^{r,s} respectively be the set of honest and malicious verifiers in a step ss in part i∈{1,2}i\\in\\{1,2\\}. We have

|H​S​V1r,s|+|M​S​V1r,s|+|H​S​V2r,s|+|M​S​V2r,s|\=|H​S​Vr,s|+|M​S​Vr,s|.|HSV\_{1}^{r,s}|+|MSV\_{1}^{r,s}|+|HSV\_{2}^{r,s}|+|MSV\_{2}^{r,s}|=|HSV^{r,s}|+|MSV^{r,s}|.

Note that |H​S​Vr,s|+|M​S​Vr,s|<|H​S​Vr,s|+2|M​S​Vr,s|<2​tH|HSV^{r,s}|+|MSV^{r,s}|<|HSV^{r,s}|+2|MSV^{r,s}|<2t\_{H} with overwhelming probability.

If some part ii has |H​S​Vir,s|+|M​S​Vir,s|≥tH|HSV\_{i}^{r,s}|+|MSV\_{i}^{r,s}|\\geq t\_{H} with non-negligible probability, e.g., 1%1\\%, then the probability that |H​S​V3−ir,s|+|M​S​V3−ir,s|≥tH|HSV\_{3-i}^{r,s}|+|MSV\_{3-i}^{r,s}|\\geq t\_{H} is very low, e.g., 10−1610^{-16} when F\=10−18F=10^{-18}. In this case, we may as well treat the smaller part as going offline, because there will not be enough verifiers in this part to generate tHt\_{H} signatures to certify a block.

Let us consider the larger part, say part 1 without loss of generality. Although |H​S​Vr,s|<tH|HSV^{r,s}|<t\_{H} with negligible probability in each step ss, when the network is partitioned, |H​S​V1r,s||HSV\_{1}^{r,s}| may be less than tHt\_{H} with some non-negligible probability. In this case the Adversary may, with some other non-negligible probability, force the binary BA protocol into a fork in round rr, with a non-empty block BrB^{r} and the empty block BϵrB^{r}\_{\\epsilon} both having tHt\_{H} valid signatures.5252 52 Having a fork with two non-empty blocks is not possible with or without partitions, except with negligible probability. For example, in a Coin-Fixed-To-0 step ss, all verifiers in H​S​V1r,sHSV\_{1}^{r,s} signed for bit 0 and H⁡(Br)H(B^{r}), and propagated their messages. All verifiers in M​S​V1r,sMSV\_{1}^{r,s} also signed 0 and H⁡(Br)H(B^{r}), but withheld their messages. Because |H​S​V1r,s|+|M​S​V1r,s|≥tH|HSV\_{1}^{r,s}|+|MSV\_{1}^{r,s}|\\geq t\_{H}, the system has enough signatures to certify BrB^{r}. However, since the malicious verifiers withheld their signatures, the users enter step s+1s+1, which is a Coin-Fixed-To-1 step. Because |H​S​V1r,s|<tH|HSV\_{1}^{r,s}|<t\_{H} due to the partition, the verifiers in H​S​V1r,s+1HSV\_{1}^{r,s+1} did not see tHt\_{H} signatures for bit 0 and they all signed for bit 1. All verifiers in M​S​V1r,s+1MSV\_{1}^{r,s+1} did the same. Because |H​S​V1r,s+1|+|M​S​V1r,s+1|≥tH|HSV\_{1}^{r,s+1}|+|MSV\_{1}^{r,s+1}|\\geq t\_{H}, the system has enough signatures to certify BϵrB^{r}\_{\\epsilon}. The Adversary then creates a fork by releasing the signatures of M​S​V1r,sMSV\_{1}^{r,s} for 0 and H⁡(Br)H(B^{r}).

Accordingly, there will be two QrQ^{r}’s, defined by the corresponding blocks of round rr. However, the fork will not continue and only one of the two branches may grow in round r+1r+1.

##### Additional Instructions for Algorand𝟐′\\bm{\\text{{Algorand}}\\,^{\\prime}\_{2}}.

When seeing a non-empty block BrB^{r} and the empty block BϵrB^{r}\_{\\epsilon}, follow the non-empty one (and the QrQ^{r} defined by it).

Indeed, by instructing the users to go with the non-empty block in the protocol, if a large amount of honest users in P​Kr+1−kPK^{r+1-k} realize there is a fork at the beginning of round r+1r+1, then the empty block will not have enough followers and will not grow. Assume the Adversary manages to partition the honest users so that some honest users see BrB^{r} (and perhaps BϵrB^{r}\_{\\epsilon}), and some only see BϵrB^{r}\_{\\epsilon}. Because the Adversary cannot tell which one of them will be a verifier following BrB^{r} and which will be a verifier following BϵrB^{r}\_{\\epsilon}, the honest users are randomly partitioned and each one of them still becomes a verifier (either with respect to BrB^{r} or with respect to BϵrB^{r}\_{\\epsilon}) in a step s\>1s>1 with probability pp. For the malicious users, each one of them may have two chances to become a verifier, one with BrB^{r} and the other with BϵrB^{r}\_{\\epsilon}, each with probability pp independently.

Let H​S​V1;Brr+1,sHSV\_{1;B^{r}}^{r+1,s} be the set of honest verifiers in step ss of round r+1r+1 following BrB^{r}. Other notations such as H​S​V1;Bϵrr+1,sHSV\_{1;B^{r}\_{\\epsilon}}^{r+1,s}, M​S​V1;Brr+1,sMSV\_{1;B^{r}}^{r+1,s} and M​S​V1;Bϵrr+1,sMSV\_{1;B^{r}\_{\\epsilon}}^{r+1,s} are similarly defined. By Chernoff bound, it is easy to see that with overwhelming probability,

|H​S​V1;Brr+1,s|+|H​S​V1;Bϵrr+1,s|+|M​S​V1;Brr+1,s|+|M​S​V1;Bϵrr+1,s|<2​tH.|HSV\_{1;B^{r}}^{r+1,s}|+|HSV\_{1;B^{r}\_{\\epsilon}}^{r+1,s}|+|MSV\_{1;B^{r}}^{r+1,s}|+|MSV\_{1;B^{r}\_{\\epsilon}}^{r+1,s}|<2t\_{H}.

Accordingly, the two branches cannot both have tHt\_{H} proper signatures certifying a block for round r+1r+1 in the same step ss. Moreover, since the selection probabilities for two steps ss and s′s^{\\prime} are the same and the selections are independent, also with overwhelming probability

|H​S​V1;Brr+1,s|+|M​S​V1;Brr+1,s|+|H​S​V1;Bϵrr+1,s′|+|M​S​V1;Bϵrr+1,s′|<2​tH,|HSV\_{1;B^{r}}^{r+1,s}|+|MSV\_{1;B^{r}}^{r+1,s}|+|HSV\_{1;B^{r}\_{\\epsilon}}^{r+1,s^{\\prime}}|+|MSV\_{1;B^{r}\_{\\epsilon}}^{r+1,s^{\\prime}}|<2t\_{H},

for any two steps ss and s′s^{\\prime}. When F\=10−18F=10^{-18}, by the union bound, as long as the Adversary cannot partition the honest users for a long time (say 10410^{4} steps, which is more than 55 hours with λ\=10\\lambda=10 seconds5353 53 Note that a user finishes a step ss without waiting for 2​λ2\\lambda time only if he has seen at least tHt\_{H} signatures for the same message. When there are not enough signatures, each step will last for 2​λ2\\lambda time.), with high probability (say 1−10−101-10^{-10}) at most one branch will have tHt\_{H} proper signatures to certify a block in round r+1r+1.

Finally, if the physical partition has created two parts with roughly the same size, then the probability that |H​S​Vir,s|+|M​S​Vir,s|≥tH|HSV\_{i}^{r,s}|+|MSV\_{i}^{r,s}|\\geq t\_{H} is small for each part ii. Following a similar analysis, even if the Adversary manages to create a fork with some non-negligible probability in each part for round rr, at most one of the four branches may grow in round r+1r+1.

### 10.2 Adversarial Partition

Second of all, the partition may be caused by the Adversary, so that the messages propagated by the honest users in one part will not reach the honest users in the other part directly, but the Adversary is able to forward messages between the two parts. Still, once a message from one part reaches an honest user in the other part, it will be propagated in the latter as usual. If the Adversary is willing to spend a lot of money, it is conceivable that he may be able to hack the Internet and partition it like this for a while.

The analysis is similar to that for the larger part in the physical partition above (the smaller part can be considered as having population 0): the Adversary may be able to create a fork and each honest user only sees one of the branches, but at most one branch may grow.

### 10.3 Network Partitions in Sum

Although network partitions can happen and a fork in one round may occur under partitions, there is no lingering ambiguity: a fork is very short-lived, and in fact lasts for at most a single round. In all parts of the partition except for at most one, the users cannot generate a new block and thus (a) realize there is a partition in the network and (b) never rely on blocks that will “vanish”.

## Acknowledgements

We would like to first acknowledge Sergey Gorbunov, coauthor of the cited Democoin system.

Most sincere thanks go to Maurice Herlihy, for many enlightening discussions, for pointing out that pipelining will improve Algorand’s throughput performance, and for greatly improving the exposition of an earlier version of this paper. Many thanks to Sergio Rajsbaum, for his comments on an earlier version of this paper. Many thanks to Vinod Vaikuntanathan, for several deep discussions and insights. Many thanks to Yossi Gilad, Rotem Hamo, Georgios Vlachos, and Nickolai Zeldovich for starting to test these ideas, and for many helpful comments and discussions.

Silvio Micali would like to personally thank Ron Rivest for innumerable discussions and guidance in cryptographic research over more than 3 decades, for coauthoring the cited micropayment system that has inspired one of the verifier selection mechanisms of Algorand.

We hope to bring this technology to the next level. Meanwhile the travel and companionship are great fun, for which we are very grateful.

## References

-   \[1\] Bitcoin Computation Waste, [http://gizmodo.com/the-worlds-most-powerful-computer-network-is-being-was-504503726](http://gizmodo.com/the-worlds-most-powerful-computer-network-is-being-was-504503726), 2013.
-   \[2\] Bitcoinwiki. Proof of Stake. [http://www.blockchaintechnologies.com/blockchain-applications](http://www.blockchaintechnologies.com/blockchain-applications) As of 5 June 2016.
-   \[3\] Coindesk.com. Bitcoin: A Peer-to-Peer Electronic Cash System [http://www.coindesk.com/ibm-reveals-proof-concept-blockchain-powered-internet-things/](http://www.coindesk.com/ibm-reveals-proof-concept-blockchain-powered-internet-things/) As of June 2016.
-   \[4\] Ethereum. Ethereum. [https://github.com/ethereum/](https://github.com/ethereum/). As of 12 June 2016.
-   \[5\] HowStuffWorks.com. How much actual money is there in the world?, [https://money.howstuffworks.com/how-much-money-is-in-the-world.htm](https://money.howstuffworks.com/how-much-money-is-in-the-world.htm). As of 5 June 2016.
-   \[6\] en.wikipedia.org/wiki/Sortition.
-   \[7\] M. Ben-Or. Another advantage of free choice: Completely asynchronous agreement protocols. Proc. 2nd Annual Symposium on Principles of Distributed Computing, ACM, New York, 1983, pp. 27-30.
-   \[8\] M. Castro and B. Liskov. Practical Byzantine Fault Tolerance, Proceedings of the Third Symposium on Operating Systems Design and Implementation. New Orleans, Louisiana, USA, 1999, pp. 173–186.
-   \[9\] D. L. Chaum, Random Sample Elections, [https://www.scribd.com/mobile/document/236881043/Random-Sample-Elections](https://www.scribd.com/mobile/document/236881043/Random-Sample-Elections).
-   \[10\] B. Chor and C. Dwork. Randomization in Byzantine agreement, in Randomness and Computation. S. Micali, ed., JAI Press, Greenwich, CT, 1989, pp. 433-498.
-   \[11\] C. Decker and R. Wattenhofer. Information Propagation in the Bitcoin Network. 13-th IEEE Conference on Peer-to-Peer Computing, 2013.
-   \[12\] D. Dolev. The Byzantine Generals Strike Again. J. Algorithms, 3, (1982), pp. 14-30.
-   \[13\] D. Dolev and H.R. Strong. Authenticated algorithms for Byzantine agreement. SIAM Journal on Computing 12 (4), 656-666.
-   \[14\] C. Dwork and M. Naor. Pricing via Processing, Or, Combatting Junk Mail. Advances in Cryptology, CRYPTO’92: Lecture Notes in Computer Science No. 740. Springer: 139–147.
-   \[15\] P. Feldman and S. Micali. An Optimal Probabilistic Algorithm for Synchronous Byzantine Agreement. (Preliminary version in STOC 88.) SIAM J. on Computing, 1997.
-   \[16\] M. Fischer. The consensus problem in unreliable distributed systems (a brief survey). Proc. International Conference on Foundations of Computation, 1983.
-   \[17\] S. Goldwasser, S. Micali, and R. Rivest. A Digital Signature Scheme Secure Against Adaptive Chosen-Message Attack. SIAM Journal of Computing, 17, No. 2, April 1988, pp. 281-308
-   \[18\] S. Gorbunov and S. Micali. Democoin: A Publicly Verifiable and Jointly Serviced Cryptocurrency. [https://eprint.iacr.org/2015/521](https://eprint.iacr.org/2015/521), May 30, 2015.
-   \[19\] J. Katz and C-Y Koo. On Expected Constant-Round Protocols for Byzantine Agreement. [https://www.cs.umd.edu/~jkatz/papers/BA.pdf](https://www.cs.umd.edu/~jkatz/papers/BA.pdf).
-   \[20\] A. Kiayias, A. Russel, B. David, and R. Oliynycov.. Ouroburos: A provably secure proof-of-stake protocol. Cryptology ePrint Archive, Report 2016/889, 2016. http://eprint.iacr.org/2016/889.
-   \[21\] S. King and S. Nadal. PPCoin: Peer-to-Peer Crypto-Currency with Proof-of-Stake, 2012.
-   \[22\] D. Lazar and Y. Gilad. Personal Communication.
-   \[23\] N. Lynch. Distributed Algorithms. Morgan Kaufmann Publishers, 1996.
-   \[24\] S. Micali. Algorand: The Efficient Public Ledger. [https://arxiv.org/abs/1607.01341](https://arxiv.org/abs/1607.01341).
-   \[25\] S. Micali. Fast And Furious Byzantine Agreement. Innovation in Theoretical Computer Science 2017. Berkeley, CA, January 2017. Single-page abstract.
-   \[26\] S. Micali. Byzantine Agreement, Made Trivial. [https://people.csail.mit.edu/silvio/SelectedScientificPapers/DistributedComputation/BYZANTINEAGREEMENTMADETRIVIAL.pdf](https://people.csail.mit.edu/silvio/SelectedScientificPapers/DistributedComputation/BYZANTINEAGREEMENTMADETRIVIAL.pdf).
-   \[27\] S. Micali, M. Rabin and S. Vadhan. Verifiable Random Functions. 40th Foundations of Computer Science (FOCS), New York, Oct 1999.
-   \[28\] S. Micali and R. L. Rivest. Micropayments Revisited. Lecture Notes in Computer Science, Vol. 2271, pp 149-163, Springer Verlag, 2002.
-   \[29\] S. Nakamoto. Bitcoin: A Peer-to-Peer Electronic Cash System. [http://www.bitcoin.org/bitcoin.pdf](http://www.bitcoin.org/bitcoin.pdf), May 2009.
-   \[30\] R. Pass and E. Shi. The Sleepy Model of Consensus. Cryptology ePrint Archive, Feb 2017, Report 2017/918.
-   \[31\] M. Pease, R. Shostak, and L. Lamport. Reaching agreement in the presence of faults. J. Assoc. Comput. Mach., 27 (1980), pp. 228-234.
-   \[32\] M. Rabin. Randomized Byzantine generals. 24th Foundations of Computer Science (FOCS), IEEE Computer Society Press, Los Alamitos, CA, 1983, pp. 403-409.
-   \[33\] R. Turpin and B. Coan. Extending binary Byzantine agreement to multivalued Byzantine agreement. Inform. Process. Lett., 18 (1984), pp. 73-76.

Experimental support, please [view the build logs](./1607.01341v9/__stdout.txt) for errors. Generated by [L A T E xml ![[LOGO]](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAOCAYAAAD5YeaVAAAAAXNSR0IArs4c6QAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB9wKExQZLWTEaOUAAAAddEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIFRoZSBHSU1Q72QlbgAAAdpJREFUKM9tkL+L2nAARz9fPZNCKFapUn8kyI0e4iRHSR1Kb8ng0lJw6FYHFwv2LwhOpcWxTjeUunYqOmqd6hEoRDhtDWdA8ApRYsSUCDHNt5ul13vz4w0vWCgUnnEc975arX6ORqN3VqtVZbfbTQC4uEHANM3jSqXymFI6yWazP2KxWAXAL9zCUa1Wy2tXVxheKA9YNoR8Pt+aTqe4FVVVvz05O6MBhqUIBGk8Hn8HAOVy+T+XLJfLS4ZhTiRJgqIoVBRFIoric47jPnmeB1mW/9rr9ZpSSn3Lsmir1fJZlqWlUonKsvwWwD8ymc/nXwVBeLjf7xEKhdBut9Hr9WgmkyGEkJwsy5eHG5vN5g0AKIoCAEgkEkin0wQAfN9/cXPdheu6P33fBwB4ngcAcByHJpPJl+fn54mD3Gg0NrquXxeLRQAAwzAYj8cwTZPwPH9/sVg8PXweDAauqqr2cDjEer1GJBLBZDJBs9mE4zjwfZ85lAGg2+06hmGgXq+j3+/DsixYlgVN03a9Xu8jgCNCyIegIAgx13Vfd7vdu+FweG8YRkjXdWy329+dTgeSJD3ieZ7RNO0VAXAPwDEAO5VKndi2fWrb9jWl9Esul6PZbDY9Go1OZ7PZ9z/lyuD3OozU2wAAAABJRU5ErkJggg==)](https://math.nist.gov/~BMiller/LaTeXML/)  .

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